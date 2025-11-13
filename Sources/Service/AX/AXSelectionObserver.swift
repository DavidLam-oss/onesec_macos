import ApplicationServices
import Cocoa
import SwiftUI

@MainActor
class AXSelectionObserver {
    static let shared = AXSelectionObserver()

    private var observer: AXObserver?
    private var appObserver: NSObjectProtocol?
    private let textChangeThrottler = Throttler(interval: 2.0)

    private init() {
        setupAppSwitchObserver()
    }

    private func setupAppSwitchObserver() {
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                log.info("Application switched to: \(app.localizedName ?? "Unknown")")
                _ = CGEvent(source: CGEventSource(stateID: .hidSystemState))
                Task { @MainActor in
                    self.startObserving()
                }
            }
        }
    }

    func startObserving() {
        stopObserving()
        guard let app = NSWorkspace.shared.frontmostApplication,
              let pid = app.processIdentifier as pid_t?,
              app.localizedName != "终端"
        else {
            return
        }

        var observer: AXObserver?
        let result = AXObserverCreate(pid, { _, _, notification, _ in
            Task { @MainActor in
                if notification as String == kAXSelectedTextChangedNotification as String {
                    AXPasteboardController.checkTextModification()
                } else if notification as String == kAXFocusedUIElementChangedNotification as String {
                    log.info("Focused UI Element Changed")
                }
            }
        }, &observer)

        guard result == .success, let observer = observer else {
            return
        }

        self.observer = observer
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

        // 监听当前焦点元素
        if let focusedElement = AXElementAccessor.getFocusedElement() {
            log.info("Start Observing: \(app.localizedName ?? "Unknown")")
            addAllNotifications(to: focusedElement)
        }
    }

    private func addAllNotifications(to element: AXUIElement) {
        guard let observer = observer else { return }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let notifications: [String] = [
            kAXSelectedTextChangedNotification as String,
            kAXFocusedUIElementChangedNotification as String,
        ]

        for notification in notifications {
            AXObserverAddNotification(observer, element, notification as CFString, selfPtr)
        }
    }

    func stopObserving() {
        if let observer = observer {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        log.info("Remove AX Observer for current app")
    }
}
