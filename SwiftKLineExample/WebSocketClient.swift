//
//  WebSocketClient.swift
//  KLineDemo
//
//  Created by iya on 2025/3/23.
//

import Foundation

public enum WebSocketMessage: Sendable {
    case text(String)
    case data(Data)
}

public enum WebSocketError: Error, Sendable, CustomStringConvertible {
    /// 连接失败
    case connectionFailed(Error)
    /// 发送失败
    case sendFailed(Error)
    /// 不合法的 url
    case invalidURL
    /// 意外断开链接
    case unexpectedClose(code: URLSessionWebSocketTask.CloseCode)
    
    public var description: String {
        switch self {
        case .connectionFailed(let error): "连接失败: \(error.localizedDescription)"
        case .sendFailed(let error): "发送失败: \(error.localizedDescription)"
        case .invalidURL: "无效的 WebSocket URL"
        case .unexpectedClose(let code): "意外断开: \(code)"
        }
    }
}

public enum ConnectionStatus: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
}

// 所有连接状态均由同一个 actor 管理，关闭连接与接收失败不会并发修改会话。
public actor WebSocketClient {
    public struct Configuration: Sendable {
        public let url: URL
        public let autoReconnect: Bool
        public let maxReconnectAttempts: Int
        public let pingInterval: TimeInterval
        
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

    public let messages: AsyncStream<WebSocketMessage>
    public let statusUpdate: AsyncStream<ConnectionStatus>

    public init(config: Configuration) {
        self.config = config
        (messages, messagesContinuation) = AsyncStream.makeStream()
        (statusUpdate, statusContinuation) = AsyncStream.makeStream()
    }

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

    /// 结束客户端及其消息流；新的订阅使用新的客户端实例。
    public func disconnect() {
        // 在取消 socket 前使旧接收回调及退避重连失效；主动关闭绝不能触发自动重连。
        generation = UUID()
        isClosed = true
        receiveTask?.cancel()
        receiveTask = nil
        clearConnection(code: .goingAway)
        setStatus(.disconnected)
        messagesContinuation.finish()
        statusContinuation.finish()
    }

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
        // resume() 并不表示握手成功，只有收到消息或 pong 才重置连续失败次数。
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
            // disconnect() 会取消退避任务，取消后不再创建新的 socket。
            return
        }
    }
}
