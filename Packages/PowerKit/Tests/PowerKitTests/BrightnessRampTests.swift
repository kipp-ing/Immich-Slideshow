import Testing
@testable import PowerKit

@MainActor
@Suite
struct BrightnessRampTests {
    @Test
    func immediateBrightnessWritesTargetInForeground() async {
        let screen = FakeScreenController()
        let manager = PowerManager(screen: screen, clock: ManualClock())

        manager.activate()
        await manager.setBrightness(0.4, animated: false)

        #expect(screen.brightnessWrites.last == 0.4)
    }

    @Test
    func immediateBrightnessClampsTarget() async {
        let screen = FakeScreenController()
        let manager = PowerManager(screen: screen, clock: ManualClock())

        manager.activate()
        await manager.setBrightness(1.5, animated: false)
        #expect(screen.brightnessWrites.last == 1.0)

        await manager.setBrightness(-0.2, animated: false)
        #expect(screen.brightnessWrites.last == 0.0)
    }

    @Test
    func animatedBrightnessRampsThroughIntermediateValuesAndEndsAtTarget() async {
        let config = PowerConfig(softDimDuration: .milliseconds(600), softDimSteps: 8)
        let screen = FakeScreenController(brightness: 0.8)
        let manager = PowerManager(screen: screen, clock: ManualClock(), config: config)

        manager.activate()
        await manager.setBrightness(0.0, animated: true)

        #expect(screen.brightnessWrites.contains { $0 > 0.0 && $0 < 0.8 })
        #expect(screen.brightnessWrites.last == 0.0)
        #expect(screen.brightnessWrites.count == config.softDimSteps)
    }

    @Test
    func brightnessSetInBackgroundIsNoOp() async {
        let screen = FakeScreenController()
        let manager = PowerManager(screen: screen, clock: ManualClock())

        manager.activate()
        manager.didEnterBackground()
        await manager.setBrightness(0.2, animated: false)

        #expect(screen.brightnessWrites.isEmpty)
    }
}
