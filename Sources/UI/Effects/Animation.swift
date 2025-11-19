import SwiftUI

enum AnimationConstants {
    static let springResponse: CGFloat = 0.5
    static let springDamping: CGFloat = 0.825
    static let morphSpringResponse: CGFloat = 1.5

    static var defaultSpring: Animation {
        .spring(response: springResponse, dampingFraction: springDamping)
    }

    static var quickSpring: Animation {
        .spring(response: 0.3, dampingFraction: 0.7)
    }

    static var morphSpring: Animation {
        .spring(response: morphSpringResponse, dampingFraction: springDamping)
    }
}

extension Animation {
    static var cardAnimation: Animation { AnimationConstants.defaultSpring }
    static var springAnimation: Animation { AnimationConstants.defaultSpring }
    static var quickSpringAnimation: Animation { AnimationConstants.quickSpring }
    static var morphAnimation: Animation { AnimationConstants.morphSpring }
}

extension CASpringAnimation {
    static func createSpringFadeInAnimation(keyPath: String) -> CASpringAnimation {
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.stiffness = 300.0
        animation.damping = 20.0
        animation.duration = animation.settlingDuration
        return animation
    }

    static func createSpringFrameMoveAnimation(keyPath: String, fromValue: NSRect, toValue: NSRect) -> CASpringAnimation {
        let springAnimation = CASpringAnimation(keyPath: keyPath)
        springAnimation.fromValue = NSValue(rect: fromValue)
        springAnimation.toValue = NSValue(rect: toValue)
        springAnimation.damping = 30
        springAnimation.stiffness = 300
        springAnimation.duration = springAnimation.settlingDuration
        return springAnimation
    }
}
