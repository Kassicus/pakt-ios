import SwiftUI

public enum PaktMotion {
    public static let quick    = Animation.easeInOut(duration: 0.12)
    public static let standard = Animation.easeInOut(duration: 0.2)
    public static let sheet    = Animation.spring(response: 0.35, dampingFraction: 0.85)
}
