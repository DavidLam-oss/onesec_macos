import SwiftUI

struct ContentCard: View {
    let panelId: UUID
    let title: String
    let content: String
    let onTap: (() -> Void)? = nil
    
    @State private var isCloseHovered = false
    @State private var isCardHovered = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 卡片主体
            cardContent
            
            // 关闭按钮
            closeButton
        }
    }
    
    // MARK: - 卡片内容

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 12) {
            // 文本内容
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.overlayText)
                    .lineLimit(1)
                
                Text(content)
                    .font(.system(size: 12))
                    .foregroundColor(.overlaySecondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.overlayBackground),
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(borderGrey.opacity(0.8), lineWidth: 1),
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 2)
        .onTapGesture {
            onTap?()
        }
        .onHover(perform: handleCardHover)
    }
    
    // MARK: - 关闭按钮

    private var closeButton: some View {
        Button(action: closeCard) {
            Image.systemSymbol("xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(isCloseHovered ? destructiveRed : Color.gray.opacity(0.5))
        }
        .buttonStyle(PlainButtonStyle())
        .onHover(perform: handleCloseHover)
        .padding(8)
        .animation(.easeInOut(duration: 0.2), value: isCloseHovered)
        .contentShape(Rectangle())
    }
    
    // MARK: - 事件处理

    private func closeCard() {
        log.info("closeCard: \(panelId)")
        OverlayController.shared.hideOverlay(uuid: panelId)
    }
    
    private func handleCardHover(_ hovering: Bool) {
        isCardHovered = hovering
        if hovering {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
    }
    
    private func handleCloseHover(_ hovering: Bool) {
        isCloseHovered = hovering
        if hovering {
            NSCursor.pointingHand.push()
        } else {
            NSCursor.pop()
        }
    }
}
