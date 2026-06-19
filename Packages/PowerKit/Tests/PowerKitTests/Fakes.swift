import Foundation
import PowerKit

@MainActor
final class FakeScreenController: ScreenControlling {
    var brightnessWrites: [Double] = []
    private var _brightness: Double
    var isIdleTimerDisabled: Bool = false

    init(brightness: Double = 0.5) {
        _brightness = brightness
    }

    var brightness: Double {
        get { _brightness }
        set {
            _brightness = newValue
            brightnessWrites.append(newValue)
        }
    }
}

struct ManualClock: PowerClock {
    func sleep(for duration: Duration) async throws {}
}
