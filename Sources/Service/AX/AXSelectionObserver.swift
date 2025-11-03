import ApplicationServices
import Cocoa
import SwiftUI

@MainActor
class AXSelectionObserver {
    static let shared = AXSelectionObserver()

    private var observer: AXObserver?
    private var currentPanelId: UUID?

    private init() {}

    func startObserving() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppDidChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        setupObserverForCurrentApp()
    }

    func stopObserving() {
        removeCurrentObserver()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func activeAppDidChange() {
        setupObserverForCurrentApp()
    }

    private func setupObserverForCurrentApp() {
        removeCurrentObserver()

        guard let app = NSWorkspace.shared.frontmostApplication,
              let pid = app.processIdentifier as pid_t?
        else {
            return
        }

        var observer: AXObserver?
        let result = AXObserverCreate(pid, { _, _, notification, refcon in
            // guard let refcon = refcon else { return }
            // let mySelf = Unmanaged<AXSelectionObserver>.fromOpaque(refcon).takeUnretainedValue()

            Task { @MainActor in
                log.info("收到通知: \(notification as String)")

                // if notification as String == kAXFocusedUIElementChangedNotification as String {
                //     mySelf.addAllNotifications(to: element)
                // } else {
                //     mySelf.handleSelectionNotification(element: element)
                // }
            }
        }, &observer)

        guard result == .success, let observer = observer else {
            return
        }

        self.observer = observer
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

        log.info("开始监听: \(app.localizedName ?? "Unknown")")

        // 监听当前焦点元素
        if let focusedElement = AXElementAccessor.getFocusedElement() {
            addAllNotifications(to: focusedElement)
        }
    }

    private func addAllNotifications(to element: AXUIElement) {
        guard let observer = observer else { return }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // 所有可能的选中文本相关通知
        let notifications: [String] = [
            kAXSelectedTextChangedNotification as String,
            "AXSelectedTextRangeChanged",
            kAXFocusedUIElementChangedNotification as String,
            kAXValueChangedNotification as String,
        ]

        for notification in notifications {
            let result = AXObserverAddNotification(observer, element, notification as CFString, selfPtr)
            if result == .success {
                log.info("✅ 添加通知: \(notification)")
            }
        }
    }

    private func removeCurrentObserver() {
        if let observer = observer {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil

        if let panelId = currentPanelId {
            OverlayController.shared.hideOverlay(uuid: panelId)
            currentPanelId = nil
        }
    }
}

extension AXSelectionObserver {
    private func handleSelectionNotification(element: AXUIElement) {
        guard let selectedText: String = AXElementAccessor.getAttributeValue(
            element: element,
            attribute: kAXSelectedTextAttribute
        ), !selectedText.isEmpty else {
            if let panelId = currentPanelId {
                OverlayController.shared.hideOverlay(uuid: panelId)
                currentPanelId = nil
            }
            return
        }

        log.info("选中文本: \(selectedText)")
        handleSelectionChanged(selectedText: selectedText)
    }

    private func handleSelectionChanged(selectedText: String) {
        if let panelId = currentPanelId {
            OverlayController.shared.hideOverlay(uuid: panelId)
        }

        currentPanelId = OverlayController.shared.showOverlayAboveSelection { panelId in
            VStack(spacing: 8) {
                Text(selectedText)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.8)))

                Button(action: {
                    OverlayController.shared.hideOverlay(uuid: panelId)
                }) {
                    Text("关闭")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}
