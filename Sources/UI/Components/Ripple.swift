import SwiftUI

struct SingleRipple: View {
    let color: Color
    let delay: Double

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.6

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 1.5)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeOut(duration: 1.2)) {
                        scale = 2.5
                        opacity = 0
                    }
                }
            }
    }
}

struct RippleEffect: View {
    let color: Color
    let rippleId: UUID

    var body: some View {
        ZStack {
            ForEach(0 ..< 3, id: \.self) { index in
                SingleRipple(color: color, delay: Double(index) * 0.35)
                    .id("\(rippleId)-\(index)")
            }
        }
    }
}
