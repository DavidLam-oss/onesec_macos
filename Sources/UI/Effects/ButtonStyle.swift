import SwiftUI

struct HoverButtonStyle: ButtonStyle {
    let normalColor: Color
    let hoverColor: Color
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovered ? hoverColor : normalColor)
            .background(isHovered ? Color.overlayButtonHoverBackground : Color.overlayButtonBackground)
            .animation(.quickSpringAnimation, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

struct HoverIconButtonStyle: ButtonStyle {
    let normalColor: Color
    let hoverColor: Color
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovered ? hoverColor : normalColor)
            .animation(.quickSpringAnimation, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

struct UnderlineTextButtonStyle: ButtonStyle {
    let normalColor: Color
    let hoverColor: Color
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 13.0, *) {
            configuration.label
                .font(.system(size: 12, weight: isHovered ? .semibold : .regular))
                .foregroundColor(isHovered ? hoverColor : normalColor)
                .underline(true, color: isHovered ? hoverColor : normalColor)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        } else {
            configuration.label
                .font(.system(size: 12, weight: isHovered ? .semibold : .regular))
                .foregroundColor(isHovered ? hoverColor : normalColor)
                .overlay(
                    Rectangle()
                        .fill(isHovered ? hoverColor : normalColor)
                        .frame(height: isHovered ? 1.5 : 1)
                        .offset(y: 7),
                    alignment: .bottom
                )
                .animation(.easeInOut(duration: 0.15), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
    }
}
