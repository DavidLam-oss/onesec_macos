import ApplicationServices
import Cocoa
import SwiftUI

@MainActor
class AXSelectionObserver {
    static let shared = AXSelectionObserver()

    private var observer: AXObserver?
    private let textChangeThrottler = Throttler(interval: 1.0)

    private init() {}

    func startObserving() {
        removeCurrentObserver()

        guard let app = NSWorkspace.shared.frontmostApplication,
              let pid = app.processIdentifier as pid_t?
        else {
            return
        }

        guard app.localizedName != "终端" else {
            return
        }

        var observer: AXObserver?
        let result = AXObserverCreate(pid, { _, _, notification, _ in
            Task { @MainActor in
                if notification as String == kAXSelectedTextChangedNotification as String {
                    AXSelectionObserver.shared.textChangeThrottler.execute {
                        AXPasteboardController.handleTextModifyNotification()
                    }
                }
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

    func stopObserving() {
        removeCurrentObserver()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func addAllNotifications(to element: AXUIElement) {
        guard let observer = observer else { return }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let notifications: [String] = [
            kAXSelectedTextChangedNotification as String,
            kAXFocusedUIElementChangedNotification as String,
            // kAXValueChangedNotification as String,
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
        log.info("Remove AX Observer for current app")
    }
}

extension AXSelectionObserver {
    private func handleSelectionNotification(element: AXUIElement) {
        guard let selectedText: String = AXElementAccessor.getAttributeValue(
            element: element,
            attribute: kAXSelectedTextAttribute
        ), !selectedText.isEmpty else {
            return
        }

        log.info("选中文本: \(selectedText)")
    }
}
