import Observation
import ThemeKit

@MainActor
@Observable
public final class InMemoryThemeStore: ThemeSettingsStore {
    public var settings: ThemeSettings

    public init(settings: ThemeSettings = ThemeSettings()) {
        self.settings = settings
    }
}
