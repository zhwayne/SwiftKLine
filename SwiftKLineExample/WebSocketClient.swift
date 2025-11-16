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

public final class WebSocketClient: @unchecked Sendable {
    
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
    
    /// 内部状态管理
    private actor State {
        var task: URLSessionWebSocketTask?
        var reconnectAttempt = 0
        var pingTask: Task<Void, Never>?
        var session: URLSession?
        
        func updateTask(_ newTask: URLSessionWebSocketTask?) {
            task = newTask
        }
        
        func setPingTask(_ newTask: Task<Void, Never>?) {
            pingTask = newTask
        }
        
        func incrementReconnectAttempt() -> Int {
            reconnectAttempt += 1
            return reconnectAttempt
        }
        
        func resetReconnectAttempt() {
            reconnectAttempt = 0
        }
        
        func setSession(_ newSession: URLSession?) {
            session = newSession
        }
    }
    
    private let state = State()
    private let config: Configuration
    
    private let messagesContinuation: AsyncStream<WebSocketMessage>.Continuation
    private let statusContinuation: AsyncStream<ConnectionStatus>.Continuation
    private var connectionStatus: ConnectionStatus = .disconnected
    
    public let messages: AsyncStream<WebSocketMessage>
    public let statusUpdate: AsyncStream<ConnectionStatus>
    
    public init(config: Configuration) {
        self.config = config
        
        // 初始化异步流
        (messages, messagesContinuation) = AsyncStream.makeStream()
        (statusUpdate, statusContinuation) = AsyncStream.makeStream()
        
        // 开始监听状态
        Task {
            await startStateMonitoring()
        }
    }
    
    public func connect() async throws {
        guard await state.task == nil else { return }
        statusContinuation.yield(.connecting)
        connectionStatus = .connecting
        
        // 创建 websocket 任务，并尝试连接
        let session = URLSession(configuration: .default)
        await state.setSession(session)
        let task = session.webSocketTask(with: config.url)
        await state.updateTask(task)
        task.resume()
        
        statusContinuation.yield(.connected)
        connectionStatus = .connected
        await state.resetReconnectAttempt()
        await startPing()
        startMessageListening()
    }
    
    public func disconnect() async {
        guard let task = await state.task else { return  }
        task.cancel(with: .goingAway, reason: nil)
        await state.updateTask(nil)
        statusContinuation.yield(.disconnected)
        connectionStatus = .disconnected
        await stopPing()
        if let session = await state.session {
            session.invalidateAndCancel()
            await state.setSession(nil)
        }
    }
    
    public func send(message: WebSocketMessage) async throws {
        guard let task = await state.task else {
            throw WebSocketError.connectionFailed(URLError(.badServerResponse))
        }
        
        let wsMessage = switch message {
        case .text(let string): URLSessionWebSocketTask.Message.string(string)
        case .data(let data): URLSessionWebSocketTask.Message.data(data)
        }
        
        do {
            try await task.send(wsMessage)
        } catch {
            throw WebSocketError.sendFailed(error)
        }
    }
}

// MARK: - 内部实现
private extension WebSocketClient {
    
    func startPing() async {
        let interval = config.pingInterval
        guard interval > 0, connectionStatus == .connected else { return }
        
        let task = Task {
            while !Task.isCancelled {
                await sendPing()
                let ns = UInt64(config.pingInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
            }
        }
        await state.setPingTask(task)
    }
    
    func sendPing() async {
        guard let task = await state.task else { return }
        task.sendPing(pongReceiveHandler: { _ in })
    }
    
    func stopPing() async {
        await state.pingTask?.cancel()
        await state.setPingTask(nil)
    }
    
    func startMessageListening() {
        Task {
            // 绑定当前 task，错误后退出循环，由重连逻辑重启
            guard let task = await state.task else { return }
            while true {
                do {
                    let message = try await task.receive()
                    handleReceivedMessage(message)
                } catch {
                    await handleReceiveError(error)
                    break
                }
            }
        }
    }
    
    func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            messagesContinuation.yield(.text(text))
        case .data(let data):
            messagesContinuation.yield(.data(data))
        @unknown default:
            break
        }
    }
    
    func handleReceiveError(_ error: Error) async {
        // 清理当前任务与会话
        if let task = await state.task {
            task.cancel(with: .abnormalClosure, reason: nil)
        }
        await state.updateTask(nil)
        if let session = await state.session {
            session.invalidateAndCancel()
            await state.setSession(nil)
        }
        if config.autoReconnect {
            try? await attemptReconnect(error)
        } else {
            statusContinuation.yield(.disconnected)
            connectionStatus = .disconnected
            messagesContinuation.finish()
        }
    }
    
    func handleConnectionError(_ error: Error) async throws {
        // 清理当前任务与会话
        if let task = await state.task {
            task.cancel(with: .abnormalClosure, reason: nil)
        }
        await state.updateTask(nil)
        if let session = await state.session {
            session.invalidateAndCancel()
            await state.setSession(nil)
        }
        if config.autoReconnect {
            try await attemptReconnect(error)
        } else {
            statusContinuation.yield(.disconnected)
            connectionStatus = .disconnected
            messagesContinuation.finish()
            throw WebSocketError.connectionFailed(error)
        }
    }
    
    func startStateMonitoring() async {
        
    }
    
    func attemptReconnect(_ error: Error) async throws {
        let attempt = await state.incrementReconnectAttempt()
        guard attempt <= config.maxReconnectAttempts else {
            statusContinuation.yield(.disconnected)
            connectionStatus = .disconnected
            messagesContinuation.finish()
            throw WebSocketError.connectionFailed(error)
        }
        
        statusContinuation.yield(.reconnecting(attempt: attempt))
        connectionStatus = .reconnecting(attempt: attempt)
        
        let delaySec = Double(min(attempt * 2, 10))
        let ns = UInt64(delaySec * 1_000_000_000)
        try? await Task.sleep(nanoseconds: ns)
        try? await connect()
    }
}
