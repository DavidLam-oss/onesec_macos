import SwiftUI

struct RecordingState {
    var volume: CGFloat = 0  // 音量值 (0-1)
    var state: RecordState = .idle
    var mode: RecordMode = .normal

    var modeColor: Color {
        mode == .normal ? auroraGreen : starlightYellow
    }
}

struct StatusIndicator: View {
    let recordState: RecordState
    let volume: CGFloat
    let mode: RecordMode

    let minInnerRatio: CGFloat = 0.2  // 内圆最小为外圆的20%
    let maxInnerRatio: CGFloat = 0.7  // 内圆最大为外圆的70%
    
    @State private var isHovered: Bool = false
    @State private var tooltipVisible: Bool = false
    @State private var tooltipOpacity: Double = 0
    @State private var isAnimating: Bool = false

    private var modeColor: Color {
        mode == .normal ? auroraGreen : starlightYellow
    }

    // 基准大小
    private let baseSize: CGFloat = 20
    
    // 外圆缩放比例
    private var outerScale: CGFloat {
        switch recordState {
        case .idle:
            1.0
        case .recording, .processing:
            1.25  // 25/20 = 1.25，放大25%
        default:
            1.0
        }
    }

    private var innerSize: CGFloat {
        let ratio = minInnerRatio + (maxInnerRatio - minInnerRatio) * volume
        return baseSize * ratio
    }

    // 外圆背景颜色
    private var outerBackgroundColor: Color {
        if isHovered {
            return Color.black
        }
        
        switch recordState {
        case .idle:
            return Color.clear
        case .recording, .processing:
            return Color.black
        default:
            return Color.clear
        }
    }

    // 边框颜色
    private var borderColor: Color {
        switch recordState {
        case .idle:
            Color(hex: "#888888B2")
        case .recording:
            Color(hex: "#888888B2")
        default:
            Color.white.opacity(0.8)
        }
    }

    private func showMenu() {
        log.info("showMenu")
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        if let button = NSApp.windows.first?.contentView {
            let location = button.bounds.origin
            menu.popUp(positioning: nil, at: location, in: button)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tooltip
            if tooltipVisible {
                VStack(spacing: 0) {
                    Text("按住 fn 开始语音输入 或  点击进行设置")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .opacity(tooltipOpacity).fixedSize()
                    
                    Spacer()
                        .frame(height: baseSize * outerScale * (isHovered ? 1.5 : 1.0) + 8)
                }
            }
            
            // StatusIndicator
            ZStack {
                // 点击响应层
                Circle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: baseSize, height: baseSize)

                // 外圆背景
                Circle()
                    .fill(outerBackgroundColor)
                    .frame(width: baseSize, height: baseSize)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)

                // 外圆
                Circle()
                    .strokeBorder(borderColor, lineWidth: 1)
                    .frame(width: baseSize, height: baseSize)

                // 内圆
                Group {
                    if recordState == .idle {
                        Circle()
                            .fill(Color(hex: "#888888B2"))
                            .frame(width: innerSize, height: innerSize)
                    } else if recordState == .recording {
                        Circle()
                            .fill(modeColor)
                            .frame(width: innerSize, height: innerSize)
                    } else if recordState == .processing {
                        Spinner(
                            color: modeColor,
                            size: 10,
                        )
                    }
                }
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: innerSize)
            }
            .frame(width: baseSize, height: baseSize)
            .contentShape(Circle())
            .scaleEffect(outerScale, anchor: .bottom)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: outerScale)
            .scaleEffect(isHovered ? 1.5 : 1.0, anchor: .bottom)
            .onHover { isHovering in
                // 防止重复触发
                guard isHovering != isHovered || !isAnimating else { return }
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isHovered = isHovering
                }
                
                if isHovering {
                    NSCursor.pointingHand.push()
                    
                    // 防止重复执行动画
                    guard !isAnimating && !tooltipVisible else { return }
                    isAnimating = true
                    
                    // 显示tooltip：先占位等resize完成再淡入
                    Task {
                        // 立即显示tooltip占位（触发窗口resize，但tooltip是透明的）
                        tooltipVisible = true
                        tooltipOpacity = 0
                        
                        // 等待布局和resize完成
                        try? await Task.sleep(nanoseconds: 300_000_000) // 100ms
                        
                        // 淡入tooltip（此时窗口已经resize完成，不会影响布局）
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            tooltipOpacity = 1
                        }
                        
                        isAnimating = false
                    }
                } else {
                    NSCursor.pop()
                    
                    // 防止重复执行动画
                    guard !isAnimating && tooltipVisible else { return }
                    isAnimating = true
                    
                    // 隐藏tooltip：先淡出再移除
                    Task {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            tooltipOpacity = 0
                        }
                        
                        // 等待动画完成
                        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                        tooltipVisible = false
                        isAnimating = false
                    }
                }
            }
            .offset(y: recordState == .idle ? 0 : -4)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: recordState)
        }
    }
}
