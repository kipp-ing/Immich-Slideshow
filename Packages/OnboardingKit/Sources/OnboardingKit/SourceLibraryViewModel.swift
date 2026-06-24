import Foundation
import ImmichClient
import Observation

/// Drives the Settings **Sources** manager (120, US2): the persisted source library
/// plus add/remove/rename/reorder/set-active operations. Add/remove/rename/move persist
/// directly; `setActive` delegates to the app-level switch (US1 `switchActiveSource`)
/// so the running slideshow restarts, then reflects the reloaded library.
@MainActor
@Observable
public final class SourceLibraryViewModel {
    public private(set) var library: SourceLibrary
    public var isBusy = false
    public var errorMessage: String?

    @ObservationIgnored private let store: any SourceLibraryStore
    @ObservationIgnored private let secretStore: any SharedLinkSecretStore
    @ObservationIgnored private let resolver: any SharedLinkResolving
    @ObservationIgnored private let onSwitchActive: (String) -> Void

    public init(
        store: any SourceLibraryStore,
        secretStore: any SharedLinkSecretStore,
        resolver: any SharedLinkResolving,
        onSwitchActive: @escaping (String) -> Void = { _ in }
    ) {
        self.store = store
        self.secretStore = secretStore
        self.resolver = resolver
        self.onSwitchActive = onSwitchActive
        self.library = store.load()
    }

    public var sources: [Source] { library.sources }
    public var activeID: String? { library.activeID }

    /// Whether `label` (trimmed) is non-empty and not already used — drives the Add
    /// button's enabled state and guards the add operations.
    public func isLabelAvailable(_ label: String) -> Bool {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !library.sources.contains { $0.label == trimmed }
    }

    public func addAlbumSource(albumID: String, label: String) {
        errorMessage = nil
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isLabelAvailable(trimmed) else {
            errorMessage = Self.duplicateLabelMessage
            return
        }

        var library = self.library
        library.add(Source(label: trimmed, kind: .album(albumID: albumID)))
        persist(library)
    }

    public func addSharedLinkSource(urlString: String, password: String?, label: String) async {
        errorMessage = nil
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isLabelAvailable(trimmed) else {
            errorMessage = Self.duplicateLabelMessage
            return
        }

        guard let parsed = SharedLinkURL.parse(urlString) else {
            errorMessage = String(localized: "Please enter a valid shared-link address.", bundle: .module)
            return
        }

        isBusy = true
        defer { isBusy = false }

        let password = password.flatMap { $0.isEmpty ? nil : $0 }
        do {
            // Validate the link (and password, if any) before saving anything; nothing
            // is persisted when it fails (Konstitution III — no half-written secret).
            _ = try await resolver.resolve(baseURL: parsed.baseURL, slug: parsed.slug, password: password)
        } catch let error as ImmichError {
            errorMessage = ConnectionError.message(for: error)
            return
        } catch {
            errorMessage = String(localized: "Unexpected response from the server.", bundle: .module)
            return
        }

        let source = Source(label: trimmed, kind: .sharedLink(baseURL: parsed.baseURL, slug: parsed.slug))
        if let password {
            try? secretStore.savePassword(password, forSourceID: source.id)
        }

        var library = self.library
        library.add(source)
        persist(library)
    }

    public func remove(id: String) {
        if case .sharedLink = library.sources.first(where: { $0.id == id })?.kind {
            secretStore.deletePassword(forSourceID: id)
        }

        var library = self.library
        library.remove(id: id)
        persist(library)
    }

    public func rename(id: String, to label: String) {
        errorMessage = nil
        var library = self.library
        library.rename(id: id, to: label.trimmingCharacters(in: .whitespacesAndNewlines))
        persist(library)
    }

    public func move(from source: IndexSet, to destination: Int) {
        var library = self.library
        library.move(from: source, to: destination)
        persist(library)
    }

    public func setActive(id: String) {
        guard id != library.activeID, library.sources.contains(where: { $0.id == id }) else {
            return
        }

        // The app layer persists the active change and restarts the running slideshow
        // (US1); reflect the persisted state locally afterwards.
        onSwitchActive(id)
        library = store.load()
    }

    private func persist(_ library: SourceLibrary) {
        self.library = library
        store.save(library)
    }

    private static var duplicateLabelMessage: String {
        String(localized: "A source with this name already exists.", bundle: .module)
    }
}
