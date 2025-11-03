import SwiftUI

struct NotificationState {
    var isVisible: Bool = false
    var opacity: Double = 0
    var title: String = ""
    var content: String = ""
}

struct NotificationCard: View {
    let title: String
    let content: String
    let modeColor: Color
    let onClose: (() -> Void)?
    let onTap: (() -> Void)?

    @State private var isCloseHovered = false
    @State private var isCardHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Image.systemSymbol("bell.fill")
                        .font(.system(size: 18))
                        .foregroundColor(modeColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // 标题
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.overlayText)
                        .lineLimit(1)

                    // 内容
                    Text(content)
                        .font(.system(size: 12))
                        .foregroundColor(.overlaySecondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 240)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.overlayBackground),
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.overlayBorder, lineWidth: 1.2)
            )
            .shadow(color: .overlayBackground.opacity(0.3), radius: 8, x: 0, y: 0)
            .onTapGesture {
                onTap?()
            }
            .onHover { hovering in
                isCardHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            if let onClose {
                Button(action: onClose) {
                    Image.systemSymbol("xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isCloseHovered ? .overlayText : .overlaySecondaryText)
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    isCloseHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .padding(12)
                .animation(.easeInOut(duration: 0.2), value: isCloseHovered)
                .contentShape(Rectangle())
            }
        }
        .scaleEffect(isCardHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isCardHovered)
    }
}
