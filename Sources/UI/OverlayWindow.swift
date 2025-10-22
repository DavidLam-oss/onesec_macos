import SwiftUI

enum OverlayType {
    case tooltip
    case settings
    case notification
}

@MainActor
class FloatingPanelController {
    static let shared = FloatingPanelController()

    private var window: NSPanel?
    private var currentType: OverlayType = .tooltip

    private init() {}

    func showOverlay(type: OverlayType = .tooltip, @ViewBuilder content: () -> some View) {
        // 如果窗口已存在，先关闭
        if window != nil {
            hideOverlay()
        }

        currentType = type
        let hosting = NSHostingView(rootView: content())

        // 先创建一个临时的 panel 来获取内容大小
        let tempPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        tempPanel.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let contentSize = hosting.fittingSize

        // 获取 StatusPanel 的位置
        guard let statusFrame = StatusPanelManager.shared.getPanelFrame() else {
            return
        }

        // 计算 overlay 的位置：StatusPanel 正上方，水平居中
        let spacing: CGFloat = 5  // StatusPanel 和 overlay 之间的间距
        let overlayX = statusFrame.origin.x + (statusFrame.width - contentSize.width) / 2
        let overlayY = statusFrame.origin.y + statusFrame.height + spacing

        let panel = NSPanel(
            contentRect: NSRect(
                x: overlayX, y: overlayY, width: contentSize.width, height: contentSize.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )

        setupPanel(panel, hosting: hosting)
        window = panel
    }

    func updateContent(type: OverlayType = .tooltip, @ViewBuilder content: () -> some View) {
        guard let window else {
            showOverlay(type: type, content: content)
            return
        }

        currentType = type

        let hosting = NSHostingView(rootView: content())

        // 获取新内容的大小
        let tempPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        tempPanel.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let contentSize = hosting.fittingSize

        // 获取 StatusPanel 的位置
        guard let statusFrame = StatusPanelManager.shared.getPanelFrame() else {
            return
        }

        // 计算新的位置
        let spacing: CGFloat = 8
        let overlayX = statusFrame.origin.x + (statusFrame.width - contentSize.width) / 2
        let overlayY = statusFrame.origin.y + statusFrame.height + spacing

        // 更新内容视图
        window.contentView = hosting

        // 平滑动画更新位置和大小
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(
                NSRect(
                    x: overlayX, y: overlayY, width: contentSize.width, height: contentSize.height),
                display: true,
            )
        }
    }

    var isVisible: Bool {
        window != nil && window?.isVisible == true
    }

    private func setupPanel(_ panel: NSPanel, hosting: NSHostingView<some View>) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = false
        panel.contentView = hosting
        panel.makeKeyAndOrderFront(nil)
    }

    func hideOverlay(type: OverlayType? = nil) {
        guard let type, currentType == type else {
            return
        }
        
        window?.close()
        window = nil
    }
}
