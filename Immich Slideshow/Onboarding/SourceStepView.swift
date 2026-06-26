//
//  SourceStepView.swift
//  Immich Slideshow
//
//  Onboarding step 2 (120, US2): add the first slideshow source after connecting —
//  an Immich album (picked from the connected server's albums) or a shared link
//  (URL + optional password). The first source added becomes active. The matching
//  confirmation step lists the saved library with the active source marked before the
//  slideshow starts. Both bind the OnboardingViewModel (connection + navigation) and a
//  SourceLibraryViewModel (the persisted library, shared with the rest of the app).
//

import ImmichClient
import OnboardingKit
import SwiftUI

struct SourceStepView: View {
    @Bindable var onboarding: OnboardingViewModel
    @Bindable var sourceLibrary: SourceLibraryViewModel

    enum Kind: Hashable { case album, sharedLink }
    @State private var kind: Kind = .album

    var body: some View {
        VStack(spacing: 0) {
            Picker("Source type", selection: $kind) {
                Text("Album").tag(Kind.album)
                Text("Shared link").tag(Kind.sharedLink)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .accessibilityIdentifier("onboarding.source.type")

            if let errorMessage = sourceLibrary.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .accessibilityIdentifier("onboarding.source.error")
            }

            switch kind {
            case .album:
                AlbumPickerView(onboarding: onboarding, sourceLibrary: sourceLibrary)
            case .sharedLink:
                Form {
                    SharedLinkSection(sourceLibrary: sourceLibrary)
                }
            }
        }
        .navigationTitle("Add a source")
        // The primary action stays pinned while the album list scrolls underneath (210, US3).
        .safeAreaInset(edge: .bottom) {
            if !sourceLibrary.sources.isEmpty {
                AddedSourcesBar(count: sourceLibrary.sources.count) {
                    onboarding.proceedToConfirm()
                }
            }
        }
        .task { await onboarding.loadAlbumsIfNeeded() }
    }
}

/// Searchable, independently scrollable album list (210, US3). A search field narrows by
/// name / year / photo count (case- and diacritic-insensitive via `AlbumSearch`); each row
/// shows a date·count subtitle; a no-results state appears when nothing matches. Tapping a
/// row adds the album; already-added albums show a checkmark and are disabled.
private struct AlbumPickerView: View {
    @Bindable var onboarding: OnboardingViewModel
    @Bindable var sourceLibrary: SourceLibraryViewModel
    @State private var searchText = ""

    private var filteredAlbums: [Album] {
        AlbumSearch.filter(onboarding.albums, query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if onboarding.albums.isEmpty {
                ContentUnavailableView {
                    Label("No albums on this server", systemImage: "photo.on.rectangle")
                } description: {
                    Text("Add a shared link instead.")
                }
                .frame(maxHeight: .infinity)
            } else if filteredAlbums.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxHeight: .infinity)
                    .accessibilityIdentifier("onboarding.album.noResults")
            } else {
                List(filteredAlbums, id: \.id) { album in
                    albumRow(album)
                }
                .listStyle(.plain)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search albums", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("onboarding.album.search")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.album.search.clear")
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func albumRow(_ album: Album) -> some View {
        let label = album.name.isEmpty ? album.id : album.name
        let isAdded = sourceLibrary.sources.contains { $0.label == label }
        Button {
            sourceLibrary.addAlbumSource(albumID: album.id, label: label)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).foregroundStyle(.primary)
                    if let subtitle = Self.subtitle(for: album) {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isAdded {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
        .accessibilityIdentifier("onboarding.album.\(album.id)")
    }

    /// "2024 · 120 photos" — the advisory date range and asset count, each omitted when the
    /// server didn't provide it. Years use a UTC calendar to match `AlbumSearch`'s haystack.
    private static func subtitle(for album: Album) -> String? {
        var parts: [String] = []
        if let dateText = dateText(album.startDate, album.endDate) { parts.append(dateText) }
        if let count = album.assetCount { parts.append(count == 1 ? "1 photo" : "\(count) photos") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func dateText(_ start: Date?, _ end: Date?) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let years = [start, end].compactMap { $0.map { calendar.component(.year, from: $0) } }
        guard let first = years.first, let last = years.last else { return nil }
        return first == last ? "\(first)" : "\(first)–\(last)"
    }
}

/// The pinned bottom bar: a compact added-count and the primary Continue action (210, US3).
private struct AddedSourcesBar: View {
    let count: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(count == 1 ? "1 source added" : "\(count) sources added")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("onboarding.source.continue")
        }
        .padding()
        .background(.bar)
    }
}

/// Shared-link form: URL + optional password + a label. The link (and password, if
/// any) is validated against the server before anything is saved.
private struct SharedLinkSection: View {
    @Bindable var sourceLibrary: SourceLibraryViewModel

    @State private var urlText = ""
    @State private var passwordText = ""
    @State private var labelText = ""

    var body: some View {
        Section {
            TextField("https://host/s/slug", text: $urlText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .accessibilityIdentifier("onboarding.sharedLink.url")
            SecureField("Password (optional)", text: $passwordText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("onboarding.sharedLink.password")
            TextField("Name", text: $labelText)
                .accessibilityIdentifier("onboarding.sharedLink.label")
        } header: {
            Text("Shared link")
        } footer: {
            if sourceLibrary.isBusy {
                ProgressView()
            } else {
                Button("Add") {
                    Task {
                        await sourceLibrary.addSharedLinkSource(
                            urlString: urlText,
                            password: passwordText,
                            label: labelText
                        )
                        if sourceLibrary.errorMessage == nil {
                            urlText = ""
                            passwordText = ""
                            labelText = ""
                        }
                    }
                }
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty
                    || labelText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("onboarding.sharedLink.add")
            }
        }
    }
}

/// Onboarding confirmation step: lists the saved library with the active source marked,
/// lets the user add another source, and starts the slideshow.
struct OnboardingConfirmStepView: View {
    @Bindable var onboarding: OnboardingViewModel
    @Bindable var sourceLibrary: SourceLibraryViewModel

    var body: some View {
        List {
            Section {
                ForEach(sourceLibrary.sources) { source in
                    HStack(spacing: 12) {
                        Image(systemName: source.kind.onboardingIconName)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(source.label)
                        Spacer()
                        if source.id == sourceLibrary.activeID {
                            Text("Active")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tint)
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(source.id == sourceLibrary.activeID ? "\(source.label), active" : source.label)
                    .accessibilityIdentifier("onboarding.confirm.row.\(source.id)")
                }
            } header: {
                Text("Your sources")
            } footer: {
                Text("The active source plays first. You can manage sources later in Settings.")
            }

            Section {
                Button("Add another source") {
                    onboarding.backToSource()
                }
                .accessibilityIdentifier("onboarding.confirm.addMore")

                Button {
                    onboarding.finish()
                } label: {
                    Text("Start slideshow")
                }
                .accessibilityIdentifier("onboarding.confirm.start")
            }
        }
        .navigationTitle("Confirm")
    }
}

private extension SourceKind {
    var onboardingIconName: String {
        switch self {
        case .album: "photo.stack"
        case .sharedLink: "link"
        }
    }
}
