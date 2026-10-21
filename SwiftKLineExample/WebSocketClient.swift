//
//  WebSocketClient.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2025/03/23.
//

import Foundation

/// The text and binary WebSocket payloads exposed by the example transport.
public enum WebSocketMessage: Sendable {
    /// A UTF-8 text message supplied by URLSession.
    case text(String)
    /// A binary message supplied by URLSession.
    case data(Data)
}

/// Transport-specific error context for the example WebSocket client.
public enum WebSocketError: Error, Sendable, CustomStringConvertible {
    /// Connection failure
    case connectionFailed(Error)
    /// Send failure
    case sendFailed(Error)
    /// Invalid WebSocket URL
    case invalidURL
    /// Unexpected socket closure
    case unexpectedClose(code: URLSessionWebSocketTask.CloseCode)
    
    /// A user-facing description of the underlying transport failure.
    public var description: String {
        switch self {
        case .connectionFailed(let error): "连接失败: \(error.localizedDescription)"
        case .sendFailed(let error): "发送失败: \(error.localizedDescription)"
        case .invalidURL: "无效的 WebSocket URL"
        case .unexpectedClose(let code): "意外断开: \(code)"
        }
    }
}

/// The example transport’s connection state, emitted through the status stream.
public enum ConnectionStatus: Sendable, Equatable {
    /// No active connection remains.
    case disconnected
    /// A socket is being created and resumed; this does not confirm a completed handshake.
    case connecting
    /// The socket has been resumed; messages or pongs establish connection health.
    case connected
    /// A bounded reconnect attempt is waiting for its backoff delay.
    case reconnecting(attempt: Int)
}

// One actor owns connection state, serializing disconnects with receive failures.
/// Serializes the example transport’s socket, receive loop, ping loop, and reconnect state.
///
/// This transport is application code rather than part of the chart package. Explicit disconnect is terminal
/// and invalidates delayed retries; a fresh chart subscription creates a fresh client.
public actor WebSocketClient {
    /// Immutable connection settings shared safely with the transport actor.
    public struct Configuration: Sendable {
        /// The WebSocket endpoint, including its exchange subscription path.
        public let url: URL
        /// Whether receive failures may create another connection.
        public let autoReconnect: Bool
        /// The maximum consecutive retry count; a received message or pong resets it.
        public let maxReconnectAttempts: Int
        /// Seconds between pings. Use a finite positive value, or a nonpositive value to disable pings.
        public let pingInterval: TimeInterval
        
        /// Creates transport configuration; the default enables three reconnect attempts and a ten-second ping interval.
        public init(
            url: URL,
            autoReconnect: Bool = true,
            maxReconnectAttempts: Int = 3,
            pingInterval: TimeInterval = 10
        ) {
            self.url = url
            self.autoReconnect = autoReconnect
            self.maxReconnectAttempts = maxReconnectAttempts
            self.pingInterval = pingInterval
        }
    }
    
    private let config: Configuration
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var generation = UUID()
    private var isClosed = false
    private var connectionStatus: ConnectionStatus = .disconnected
    private let messagesContinuation: AsyncStream<WebSocketMessage>.Continuation
    private let statusContinuation: AsyncStream<ConnectionStatus>.Continuation

    /// The payload stream with a 512-message newest buffer; older buffered payloads may be dropped.
    public let messages: AsyncStream<WebSocketMessage>
    /// The connection-status stream retaining only the latest buffered transition.
    public let statusUpdate: AsyncStream<ConnectionStatus>

    /// Creates a transport actor and its streams without opening a connection.
    public init(config: Configuration) {
        self.config = config
        (messages, messagesContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(512))
        (statusUpdate, statusContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    /// Creates and resumes a socket and starts receive/ping loops unless one is already active.
    ///
    /// Cancellation is checked before setup. A resumed socket is reported as connected before handshake confirmation;
    /// the first message or pong establishes health. Calling this after disconnect throws a cancellation error.
    public func connect() async throws {
        try Task.checkCancellation()
        guard !isClosed else { throw URLError(.cancelled) }
        guard task == nil else { return }
        setStatus(.connecting)
        let session = URLSession(configuration: .default)
        let socket = session.webSocketTask(with: config.url)
        self.session = session
        task = socket
        socket.resume()
        setStatus(.connected)
        startPing(socket: socket)
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await socket.receive()
                    await self?.handleReceivedMessage(message, socket: socket)
                } catch {
                    await self?.handleReceiveError(error, socket: socket)
                    break
                }
            }
        }
    }

    /// Permanently closes the socket, invalidates reconnect work, cancels transport tasks, and finishes both streams.
    public func disconnect() {
        // Invalidate receive callbacks and backoff retries before cancelling the socket; explicit shutdown must not reconnect.
        generation = UUID()
        isClosed = true
        receiveTask?.cancel()
        receiveTask = nil
        clearConnection(code: .goingAway)
        setStatus(.disconnected)
        messagesContinuation.finish()
        statusContinuation.finish()
    }

    /// Sends a text or binary payload through the active socket, throwing a connection or send error on failure.
    public func send(message: WebSocketMessage) async throws {
        guard let task else {
            throw WebSocketError.connectionFailed(URLError(.badServerResponse))
        }
        let wsMessage = switch message {
        case .text(let string): URLSessionWebSocketTask.Message.string(string)
        case .data(let data): URLSessionWebSocketTask.Message.data(data)
        }
        do { try await task.send(wsMessage) }
        catch { throw WebSocketError.sendFailed(error) }
    }

    private func setStatus(_ status: ConnectionStatus) {
        connectionStatus = status
        statusContinuation.yield(status)
    }

    private func clearConnection(code: URLSessionWebSocketTask.CloseCode) {
        pingTask?.cancel()
        pingTask = nil
        task?.cancel(with: code, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func startPing(socket: URLSessionWebSocketTask) {
        let interval = config.pingInterval
        guard interval > 0 else { return }
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        socket.sendPing { error in
                            if let error { continuation.resume(throwing: error) }
                            else { continuation.resume() }
                        }
                    }
                    await self?.markConnectionHealthy(socket: socket)
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch { break }
            }
        }
    }

    private func markConnectionHealthy(socket: URLSessionWebSocketTask) {
        guard task === socket else { return }
        // Socket resume does not confirm a handshake; only a message or pong resets consecutive failure attempts.
        reconnectAttempt = 0
    }

    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message, socket: URLSessionWebSocketTask) {
        guard task === socket else { return }
        markConnectionHealthy(socket: socket)
        switch message {
        case .string(let text): messagesContinuation.yield(.text(text))
        case .data(let data): messagesContinuation.yield(.data(data))
        @unknown default: break
        }
    }

    /// Clears the failed socket, applies bounded backoff, and checks generation identity before attempting reconnection.
    private func handleReceiveError(_ error: Error, socket: URLSessionWebSocketTask) async {
        guard task === socket else { return }
        clearConnection(code: .abnormalClosure)
        reconnectAttempt += 1
        guard config.autoReconnect, reconnectAttempt <= config.maxReconnectAttempts else {
            isClosed = true
            setStatus(.disconnected)
            messagesContinuation.finish()
            statusContinuation.finish()
            return
        }
        let generation = generation
        setStatus(.reconnecting(attempt: reconnectAttempt))
        do {
            try await Task.sleep(nanoseconds: UInt64(min(reconnectAttempt * 2, 10)) * 1_000_000_000)
            guard generation == self.generation else { return }
            try await connect()
        } catch {
            // Disconnect invalidates pending backoff work, preventing another socket from being created.
            return
        }
    }
}
