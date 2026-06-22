@MainActor
public protocol ThemeSettingsStore: AnyObject {
    var settings: ThemeSettings { get set }
}
