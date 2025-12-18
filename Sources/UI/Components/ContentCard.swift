import AppKit
import SwiftUI

struct ActionButton {
    let title: String
    let action: () -> Void
    let clickToClose: Bool = true
}

struct ContentCard<CustomContent: View>: View {
    let panelID: UUID
    let title: String
    let content: String
    let onTap: (() -> Void)?
    let actionButtons: [ActionButton]?
    let customContent: (() -> CustomContent)?
    let cardWidth: CGFloat
    let panelType: PanelType?

    private let autoCloseDuration = 9
    private let maxContentHeight: CGFloat = 200

    @State private var isContentCopied = false
    @State private var showActionBar = true
    @State private var contentHeight: CGFloat = 0
    @State private var remainingSeconds = 9
    @State private var timerTask: Task<Void, Never>?
    @State private var isHovering = false
    @State private var hasBeenHovered = false
    @State private var frontmostAppIcon: NSImage?

    init(
        panelID: UUID,
        title: String,
        content: String = "",
        onTap: (() -> Void)? = nil,
        actionButtons: [ActionButton]? = nil,
        cardWidth: CGFloat = 300,
        showActionBar: Bool = true,
        panelType: PanelType? = nil,
        @ViewBuilder customContent: @escaping () -> CustomContent
    ) {
        self.panelID = panelID
        self.title = title
        self.content = content
        self.onTap = onTap
        self.actionButtons = actionButtons
        self.cardWidth = cardWidth
        self.showActionBar = showActionBar
        self.panelType = panelType
        self.customContent = customContent
    }

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            cardContent
        }
        .frame(width: cardWidth)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                // Title Bar
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image.systemSymbol(panelType?.titleIcon ?? "mic")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.overlayText)
                        Text(title)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.overlayText)
                            .lineLimit(1)
                    }

                    Spacer()

                    ZStack {
                        if let appIcon = frontmostAppIcon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 16, height: 16)
                                .opacity(isHovering ? 0 : 1)
                                .scaleEffect(isHovering ? 0.8 : 1)
                                .animation(.easeInOut(duration: 0.2), value: isHovering)
                        }

                        Button(action: closeCard) {
                            Image.systemSymbol("xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .symbolAppearEffect(isActive: isHovering)
                        }
                        .buttonStyle(HoverIconButtonStyle(normalColor: .overlayPlaceholder, hoverColor: .overlayText))
                    }
                }

                Rectangle()
                    .fill(Color.overlayBorder.opacity(0.5))
                    .frame(height: 1.4).padding(.horizontal, -13).padding(.bottom, 1)

                // Content
                if let customContent = customContent {
                    customContent()
                } else {
                    ScrollView(.vertical, showsIndicators: contentHeight > maxContentHeight) {
                        Text(content)
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundColor(.overlaySecondaryText)
                            .lineSpacing(3.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.onAppear {
                                        contentHeight = geometry.size.height
                                    }
                                }
                            )
                    }
                    .tryScrollDisabled(contentHeight <= maxContentHeight)
                    .frame(maxHeight: maxContentHeight)
                }

                // Footer
                if showActionBar {
                    HStack {
                        Spacer()
                        Button(action: handleCopyContent) {
                            HStack(spacing: 4) {
                                Image.systemSymbol(isContentCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 12, weight: .semibold))
                                    .symbolReplaceEffect(value: isContentCopied)
                                    .frame(height: 12)
                                    .symbolAppearEffect(isActive: isHovering)

                                Text("复制").font(.system(size: 12, weight: .semibold))
                                    .opacity(isHovering ? 1.0 : 0.0)
                                    .animation(.easeInOut(duration: 0.2), value: isHovering)
                            }
                        }
                        .buttonStyle(HoverIconButtonStyle(normalColor: .overlayPlaceholder, hoverColor: .overlayText))
                        .disabled(isContentCopied)
                        .opacity(isContentCopied ? 0.5 : 1.0)
                    }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)

            // Bottom Timer Tip
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.overlayPrimary.opacity(0.3))
                    .frame(height: 3.5)

                Rectangle()
                    .fill(Color.overlayPrimary)
                    .frame(width: cardWidth * CGFloat(remainingSeconds) / CGFloat(autoCloseDuration), height: 3)
                    .animation(.linear(duration: 1.0), value: remainingSeconds)
            }
            .frame(height: 3.5)
            .opacity(hasBeenHovered ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: hasBeenHovered)
        }
        .background(Color.overlayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.overlayBorder, lineWidth: 1.2)
        )
        .shadow(color: .overlayBackground.opacity(0.2), radius: 6, x: 0, y: 0)
        .onTapGesture { onTap?() }
        .compatibleHover { hovering in
            isHovering = hovering
            if hovering && !hasBeenHovered {
                hasBeenHovered = true
                stopAutoCloseTimer()
            }
        }
        .onAppear {
            startAutoCloseTimer()
            fetchFrontmostAppIcon()
        }
        .onDisappear { stopAutoCloseTimer() }
    }

    private func closeCard() {
        stopAutoCloseTimer()
        OverlayController.shared.hideOverlay(uuid: panelID)
    }

    private func handleCopyContent() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)

        withAnimation {
            isContentCopied = true
        }

        Task {
            try? await sleep(3000)
            withAnimation {
                isContentCopied = false
            }
        }

        closeCard()
    }

    private func startAutoCloseTimer() {
        timerTask = Task { @MainActor in
            var currentSeconds = autoCloseDuration
            while currentSeconds >= 0 {
                guard !Task.isCancelled else { return }
                guard !hasBeenHovered else { return }

                remainingSeconds = currentSeconds
                if currentSeconds == 0 {
                    closeCard()
                    return
                }
                currentSeconds -= 1

                try? await sleep(1000)
            }
        }
    }

    private func stopAutoCloseTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func fetchFrontmostAppIcon() {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            frontmostAppIcon = frontmostApp.icon
        }
    }
}

extension ContentCard where CustomContent == EmptyView {
    init(
        panelID: UUID,
        title: String,
        content: String,
        onTap: (() -> Void)? = nil,
        actionButtons: [ActionButton]? = nil,
        cardWidth: CGFloat = 250,
        panelType: PanelType? = nil
    ) {
        self.panelID = panelID
        self.title = title
        self.content = content
        self.onTap = onTap
        self.actionButtons = actionButtons
        self.cardWidth = cardWidth
        self.panelType = panelType
        customContent = nil
    }
}

extension ContentCard {
    static func show(title: String, content: String, onTap: (() -> Void)? = nil, actionButtons: [ActionButton]? = nil, cardWidth: CGFloat = 250, spacingX: CGFloat = 0, spacingY: CGFloat = 0, panelType: PanelType? = nil) {
        OverlayController.shared.showOverlay(content: { panelID in
            ContentCard<EmptyView>(panelID: panelID, title: title, content: content, onTap: onTap, actionButtons: actionButtons, cardWidth: cardWidth, panelType: panelType)
        }, spacingX: spacingX, spacingY: spacingY, panelType: panelType)
    }

    static func showAboveSelection(title: String, content: String, onTap: (() -> Void)? = nil, actionButtons: [ActionButton]? = nil, cardWidth: CGFloat = 250, spacingX: CGFloat = 0, spacingY: CGFloat = 0, panelType: PanelType? = nil) {
        OverlayController.shared.showOverlayAboveSelection(content: { panelID in
            ContentCard<EmptyView>(panelID: panelID, title: title, content: content, onTap: onTap, actionButtons: actionButtons, cardWidth: cardWidth, panelType: panelType)
        }, spacingX: spacingX, spacingY: spacingY, panelType: panelType)
    }
}
