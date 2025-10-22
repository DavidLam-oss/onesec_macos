import AppKit
import Combine
import SwiftUI

struct StatusView: View {
    @State var recording = RecordingState()
    @State var menuBuilder: MenuBuilder?

    private let overlay = FloatingPanelController.shared

    // 显示菜单
    private func showMenu() {
        if menuBuilder == nil {
            menuBuilder = MenuBuilder(onShortcutSettings: toggleShortcutSettings)
        }

        if let button = NSApp.windows.first?.contentView {
            menuBuilder?.showMenu(in: button)
        }
    }

    // 切换快捷键设置卡片显示/隐藏
    private func toggleShortcutSettings() {
        if overlay.isVisible {
            overlay.hideOverlay()
        } else {
            overlay.showOverlay(type: .settings) {
                ShortcutSettingsCard(onClose: {
                    overlay.hideOverlay(type: .settings)
                })
            }
        }
    }

    // 显示通知的方法
    private func showNotificationMessage(title: String, content: String, autoHide: Bool = true) {
        overlay.showOverlay(type: .notification) {
            NotificationCard(
                title: title,
                content: content,
                modeColor: recording.modeColor,
            )
        }

        if autoHide {
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                overlay.hideOverlay(type: .notification)
            }
        }
    }

    var body: some View {
        VStack {
            // 状态指示器
            StatusIndicator(
                recordState: recording.state,
                volume: recording.volume,
                mode: recording.mode,
            ).onTapGesture {
                // 点击时隐藏 tooltip 并显示菜单
                overlay.hideOverlay(type: .tooltip)
                showMenu()
            }
        }.padding([.top, .leading, .trailing], 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onReceive(
                EventBus.shared.events
                    .receive(on: DispatchQueue.main),
            ) { event in
                handleEvent(event)
            }
    }

    private func handleEvent(_ event: AppEvent) {
        switch event {
        case .volumeChanged(let volume):
            recording.volume = min(1.0, max(0.0, CGFloat(volume)))
        case .recordingStarted(_, _, _, let recordMode):
            recording.mode = recordMode
            recording.state = .recording
        case .recordingStopped:
            recording.state = .processing
            recording.volume = 0
        case .serverResultReceived:
            recording.state = .idle
        case .modeUpgraded(let from, let to, _):
            log.info("statusView receive modeUpgraded \(from) \(to)")
            if to == .command {
                recording.mode = to
            }
        case .notificationReceived(let notificationType):
            log.info("notificationReceived: \(notificationType)")
            recording.state = .idle
            showNotificationMessage(
                title: notificationType.title, content: notificationType.content,
            )
        default:
            break
        }
    }
}
