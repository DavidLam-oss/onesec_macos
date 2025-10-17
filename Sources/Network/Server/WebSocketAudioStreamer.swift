//
//  WebSocketAudioStreamer.swift
//  OnesecCore
//
//  Created by 王晓雨 on 2025/10/15.
//

import AppKit
import Combine
import Foundation
import Starscream

class WebSocketAudioStreamer: @unchecked Sendable {
    private var ws: WebSocket?

    private var cancellables = Set<AnyCancellable>()

    var connectionState: ConnState = .disconnected

    // Reconnect 配置
    let maxRetryCount = 10
    var currentRetryCount = 0

    init() {
        initializeMessageListener()
    }

    func connect() {
        guard connectionState != .connecting else {
            log.info("WebSocket already connecting")
            return
        }

        if ws != nil { disconnect() }
        connectionState = .connecting

        let serverURL = URL(string: "wss://\(Config.SERVER)")!

        var request = URLRequest(url: serverURL, timeoutInterval: 60)
        request.setValue("Bearer \(Config.AUTH_TOKEN)", forHTTPHeaderField: "Authorization")

        // 创建 Starscream WebSocket
        // 使用更宽松的SSL配置来支持自签名证书
        let pinner = FoundationSecurity(allowSelfSigned: true)
        ws = WebSocket(request: request, certPinner: pinner)
        ws?.delegate = self
        ws?.connect()

        log.info("WebSocket start connect with token \(Config.AUTH_TOKEN) \(serverURL)")
    }

    func disconnect() {
        connectionState = .disconnected
        currentRetryCount = 0
        ws?.disconnect()
        ws = nil

        log.info("WebSocket disconnect")
    }

    /// 重新连接触发时机为
    /// - 连接错误（error）
    /// - 服务器建议重连（reconnectSuggested）
    /// - 对端关闭连接（peerClosed）
    /// - 用户配置变更 (userConfigChanged)
    func scheduleReconnect(reason: String) {
        guard connectionState != .connecting else {
            log.warning("Already connecting, skip reconnect")
            return
        }

        currentRetryCount += 1

        if currentRetryCount > maxRetryCount {
            log.error("WebSocket reached max retry count, stop reconnecting")
            return
        }

        // 指数退避策略：1s, 2s, 4s, 8s, 16s，最多 30s
        let delay = min(pow(2.0, Double(currentRetryCount - 1)), 30.0)

        log.info("WebSocket reconnecting in \(delay)s, reason: \(reason), attempt: \(currentRetryCount)")

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }
}

// MARK: - 消息处理

extension WebSocketAudioStreamer {
    func initializeMessageListener() {
        EventBus.shared.events
            .sink { [weak self] event in
                guard let self else { return }

                switch event {
                case .recordingStarted(let appInfo, let focusContext, let focusElementInfo, let recordMode):
                    sendStartRecording(
                        appInfo: appInfo,
                        focusContext: focusContext,
                        focusElementInfo: focusElementInfo,
                        recordMode: recordMode
                    )

                case .recordingStopped:
                    sendStopRecording()

                case .modeUpgraded(let fromMode, let toMode, let focusContext):
                    sendModeUpgrade(fromMode: fromMode, toMode: toMode, focusContext: focusContext)

                case .audioDataReceived(let data): sendAudioData(data)

                case .userConfigChanged:
                    currentRetryCount = 0
                    connect()

                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // TODO: 发到队列
    func sendAudioData(_ audioData: Data) {
        guard connectionState == .connected, let ws else {
            return
        }

        ws.write(data: audioData)
    }

    func sendMessage(_ text: String) {
        guard connectionState == .connected, let ws else {
            return
        }

        ws.write(string: text)
    }

    func sendStartRecording(
        appInfo: AppInfo? = nil,
        focusContext: FocusContext? = nil,
        focusElementInfo: FocusElementInfo? = nil,
        recordMode: RecordMode = .normal
    ) {
        var data: [String: Any] = ["recognition_mode": recordMode.rawValue]

        if let appInfo {
            data["app_info"] = appInfo.toJSON()
        }

        if let focusContext {
            data["focus_context"] = focusContext.toJSON()
        }

        if let focusElementInfo {
            data["focus_element_info"] = focusElementInfo.toJSON()
        }

        sendWebSocketMessage(type: .startRecording, data: data)
    }

    func sendStopRecording() {
        sendWebSocketMessage(type: .stopRecording)
    }

    func sendModeUpgrade(fromMode: RecordMode, toMode: RecordMode, focusContext: FocusContext? = nil) {
        var data: [String: Any] = [
            "from_mode": fromMode.rawValue,
            "to_mode": toMode.rawValue
        ]

        if let focusContext {
            data["focus_context"] = focusContext.toJSON()
        }

        sendWebSocketMessage(type: .modeUpgrade, data: data)
    }

    private func sendWebSocketMessage(type: MessageType, data: [String: Any]? = nil) {
        guard let jsonStr = WebSocketMessage.create(type: type, data: data).toJSONString() else {
            log.error("Failed to create \(type) message")
            return
        }

        log.debug("Send to server \(type): \(jsonStr)")
        sendMessage(jsonStr)
    }

    func didReceiveMessage(_ json: [String: Any]) {
        guard let data = json["data"] as? [String: Any] else {
            return
        }

        guard let summary = data["summary"] as? String else {
            return
        }

        let serverTime = data["server_time"] as? Int
        EventBus.shared.publish(.serverResultReceived(summary: summary, serverTime: serverTime))
    }
}
