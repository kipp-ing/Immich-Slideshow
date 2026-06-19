@MainActor
public protocol ScreenControlling: AnyObject {
    var brightness: Double { get set }
    var isIdleTimerDisabled: Bool { get set }
}
