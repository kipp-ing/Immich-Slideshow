import SlideshowKit
import ThemeKit
import Testing

// US2 — the pure mapping from the persisted Transition enum to a SwiftUI-free
// descriptor. Visual correctness is simulator-verified; here we lock the contract
// that drives the view, especially that "none" disables animation entirely (R5).

@Test func transitionDescriptorMapsStyleForEachCase() {
    #expect(Transition.crossfade.descriptor.style == .crossfade)
    #expect(Transition.slide.descriptor.style == .slide)
    #expect(Transition.dissolve.descriptor.style == .dissolve)
    #expect(Transition.none.descriptor.style == .none)
}

@Test func onlyNoneDisablesAnimation() {
    #expect(Transition.crossfade.descriptor.animates)
    #expect(Transition.slide.descriptor.animates)
    #expect(Transition.dissolve.descriptor.animates)
    #expect(!Transition.none.descriptor.animates)
}
