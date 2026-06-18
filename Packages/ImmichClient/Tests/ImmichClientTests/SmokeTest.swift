import Testing
@testable import ImmichClient

// Smoke-Test: bestätigt, dass Swift Testing korrekt verdrahtet ist und die Suite grün läuft.
// Wird entfernt, sobald die ersten echten TDD-Tests existieren.
@Test func moduleScaffoldIsWired() {
    #expect(ImmichClientModule.scaffold)
}
