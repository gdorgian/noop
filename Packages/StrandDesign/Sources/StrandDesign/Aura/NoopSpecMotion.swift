import SwiftUI

public enum NoopSpecMotion {
    public static let enter = Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.30)
    public static let enterRise: CGFloat = 9
    public static let sheet = Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.34)
    public static let toggleTrack = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.22)
    public static let toggleKnob = Animation.timingCurve(0.34, 1.25, 0.64, 1, duration: 0.24)
    public static let segment = Animation.easeInOut(duration: 0.18)
    public static let gaugeTick = Animation.easeInOut(duration: 0.28)
    public static let chargeBar = Animation.easeInOut(duration: 0.50)
    public static let chargeDrain = Animation.timingCurve(0.215, 0.61, 0.355, 1, duration: 1.15)
    public static let buttonPressed = Animation.easeOut(duration: 0.12)
    public static let breathDuration: Double = 16
    public static let breathPhase: Double = 4
    public static let sheenDuration: Double = 24

    public static let enterReduced = Animation.easeOut(duration: 0.20)
    public static let chargeDrainReduced = Animation.easeOut(duration: 0.20)
    public static let breathHeldScale: CGFloat = 1
}
