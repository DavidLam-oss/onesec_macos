import Foundation

enum ConnState: Equatable {
    case preparing
    case disconnected
    case connecting
    case failed
    case connected(_ session: SessionState)
    case cancelled
    case manualDisconnected // 手动断开
}

extension ConnState {
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

enum SessionState: Equatable {
    case idle // 会话空闲/待确认
    case active // 会话正常激活
    case errorOccurred // 会话发生过错误
}

extension SessionState: CustomStringConvertible {
    var description: String {
        switch self {
        case .idle: return "idle"
        case .active: return "active"
        case .errorOccurred: return "errorOccurred"
        }
    }
}
