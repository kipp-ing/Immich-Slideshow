import Foundation
import Observation

@MainActor
@Observable
public final class UserDefaultsThemeStore: ThemeSettingsStore {
    private var _settings: ThemeSettings
    private let defaults: UserDefaults

    public var settings: ThemeSettings {
        get { _settings }
        set {
            var clamped = newValue
            clamped.duration = Self.clamp(newValue.duration)
            _settings = clamped
            persist(clamped)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        _settings = Self.load(from: defaults)
    }

    static func load(from defaults: UserDefaults) -> ThemeSettings {
        var settings = ThemeSettings()

        if let rawValue = defaults.string(forKey: Keys.order),
           let order = PlayOrder(rawValue: rawValue) {
            settings.order = order
        }

        if let object = defaults.object(forKey: Keys.durationSeconds),
           let seconds = secondsValue(from: object) {
            settings.duration = clamp(.seconds(seconds))
        }

        if let rawValue = defaults.string(forKey: Keys.transition),
           let transition = Transition(rawValue: rawValue) {
            settings.transition = transition
        }

        if defaults.object(forKey: Keys.kenBurns) != nil {
            settings.kenBurns = defaults.bool(forKey: Keys.kenBurns)
        }

        if let rawValue = defaults.string(forKey: Keys.fit),
           let fit = ImageFit(rawValue: rawValue) {
            settings.fit = fit
        }

        if let rawValue = defaults.string(forKey: Keys.quality),
           let quality = ImageQuality(rawValue: rawValue) {
            settings.quality = quality
        }

        if defaults.object(forKey: Keys.clockIsOn) != nil {
            settings.clock.isOn = defaults.bool(forKey: Keys.clockIsOn)
        }

        if let rawValue = defaults.string(forKey: Keys.clockCorner),
           let corner = ClockCorner(rawValue: rawValue) {
            settings.clock.corner = corner
        }

        if defaults.object(forKey: Keys.clockShowDate) != nil {
            settings.clock.showDate = defaults.bool(forKey: Keys.clockShowDate)
        }

        return settings
    }

    static func clamp(_ duration: Duration) -> Duration {
        min(max(duration, ThemeSettings.durationRange.lowerBound), ThemeSettings.durationRange.upperBound)
    }

    private func persist(_ settings: ThemeSettings) {
        defaults.set(settings.order.rawValue, forKey: Keys.order)
        defaults.set(Self.seconds(from: settings.duration), forKey: Keys.durationSeconds)
        defaults.set(settings.transition.rawValue, forKey: Keys.transition)
        defaults.set(settings.kenBurns, forKey: Keys.kenBurns)
        defaults.set(settings.fit.rawValue, forKey: Keys.fit)
        defaults.set(settings.quality.rawValue, forKey: Keys.quality)
        defaults.set(settings.clock.isOn, forKey: Keys.clockIsOn)
        defaults.set(settings.clock.corner.rawValue, forKey: Keys.clockCorner)
        defaults.set(settings.clock.showDate, forKey: Keys.clockShowDate)
    }

    private static func seconds(from duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    private static func secondsValue(from object: Any) -> Double? {
        guard let number = object as? NSNumber else {
            return nil
        }

        let seconds = number.doubleValue
        return seconds.isFinite ? seconds : nil
    }

    private enum Keys {
        static let order = "theme.order"
        static let durationSeconds = "theme.durationSeconds"
        static let transition = "theme.transition"
        static let kenBurns = "theme.kenBurns"
        static let fit = "theme.fit"
        static let quality = "theme.quality"
        static let clockIsOn = "theme.clock.isOn"
        static let clockCorner = "theme.clock.corner"
        static let clockShowDate = "theme.clock.showDate"
    }
}
