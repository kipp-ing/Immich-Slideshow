//
//  SourceLibraryView.swift
//  Immich Slideshow
//
//  Settings → Sources (120, US2): manage the saved slideshow sources (Immich albums
//  and shared links). Tap a source to make it active — the running slideshow restarts
//  from it (the view model delegates to the app-level switch). Swipe to rename/remove,
//  reorder via the edit button, and add a new album (picker) or shared link (resolve-first;
//  a password is asked for only when the link needs one — 210, US4).
//

import ImmichClient
import OnboardingKit
import SwiftUI

struct SourceLibraryView: View {
    @Bindable var viewModel: SourceLibraryViewModel
    var makeServerAPI: () async -> (any ImmichAPI)? = { nil }

    @State private var showAddSheet = false
    @State private var renameTarget: Source?
    @State private var renameText = ""

    var body: some View {
        List {
            Section {
                ForEach(viewModel.sources) { source in
                    Button {
                        viewModel.setActive(id: source.id)
                    } label: {
                        SourceRow(source: source, isActive: source.id == viewModel.activeID)
                    }
                    .accessibilityIdentifier("sources.row.\(source.id)")
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.remove(id: source.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            renameText = source.label
                            renameTarget = source
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onMove { viewModel.move(from: $0, to: $1) }
            } footer: {
                if viewModel.sources.isEmpty {
                    Text("No source yet. Add an album or a shared link.")
                } else {
                    Text("Tap a source to make it active.")
                }
            }
        }
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.errorMessage = nil
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("sources.add")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSourceView(viewModel: viewModel, makeServerAPI: makeServerAPI)
        }
        .alert("Rename", isPresented: renameAlertPresented, presenting: renameTarget) { source in
            TextField("Name", text: $renameText)
                .accessibilityIdentifier("sources.rename.field")
            Button("Save") { viewModel.rename(id: source.id, to: renameText) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var renameAlertPresented: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }
}

/// One row in the source list: a kind icon, the label, a subtitle locator, and an
/// "Aktiv" marker on the active source (also surfaced in the accessibility label).
private struct SourceRow: View {
    let source: Source
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.kind.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.label)
                    .foregroundStyle(.primary)
                Text(source.kind.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isActive {
                Text("Active")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isActive ? "\(source.label), active" : source.label)
    }
}

/// Add-source sheet: pick the kind (album picker or shared-link form), then add. The
/// album picker lists the server's albums via the API key; the shared-link form
/// validates the link (and password, if any) before saving anything.
private struct AddSourceView: View {
    @Bindable var viewModel: SourceLibraryViewModel
    var makeServerAPI: () async -> (any ImmichAPI)?

    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind = .album

    enum Kind: Hashable { case album, sharedLink }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Album").tag(Kind.album)
                    Text("Shared link").tag(Kind.sharedLink)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("sources.add.type")

                // Album-add errors surface here; the shared-link form reports its own
                // resolve / password errors inline (210, US4).
                if kind == .album, let errorMessage = viewModel.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("sources.add.error")
                }

                switch kind {
                case .album:
                    AddAlbumSection(viewModel: viewModel, makeServerAPI: makeServerAPI) { dismiss() }
                case .sharedLink:
                    SharedLinkAddForm(
                        sourceLibrary: viewModel,
                        idPrefix: "sources.add",
                        submitIDSuffix: "submit"
                    ) { dismiss() }
                }
            }
            .navigationTitle("Add source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("sources.add.cancel")
                }
            }
        }
    }
}

/// Lists the server's albums; tapping one adds it as a source (label = album name).
private struct AddAlbumSection: View {
    @Bindable var viewModel: SourceLibraryViewModel
    var makeServerAPI: () async -> (any ImmichAPI)?
    var onAdded: () -> Void

    @State private var albums: [Album] = []
    @State private var phase: Phase = .loading

    enum Phase { case loading, loaded, failed }

    var body: some View {
        Section {
            switch phase {
            case .loading:
                ProgressView()
            case .failed:
                Label("Couldn't load albums", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
            case .loaded where albums.isEmpty:
                Label("No albums", systemImage: "photo.on.rectangle")
                    .foregroundStyle(.secondary)
            case .loaded:
                ForEach(albums, id: \.id) { album in
                    Button {
                        viewModel.addAlbumSource(albumID: album.id, label: album.name.isEmpty ? album.id : album.name)
                        if viewModel.errorMessage == nil { onAdded() }
                    } label: {
                        Text(album.name.isEmpty ? album.id : album.name)
                    }
                    .accessibilityIdentifier("sources.album.\(album.id)")
                }
            }
        } header: {
            Text("Choose album")
        }
        .task {
            guard let api = await makeServerAPI() else { phase = .failed; return }
            do {
                albums = try await api.albums()
                phase = .loaded
            } catch {
                phase = .failed
            }
        }
    }
}

private extension SourceKind {
    var iconName: String {
        switch self {
        case .album: "photo.stack"
        case .sharedLink: "link"
        }
    }

    var subtitle: String {
        switch self {
        case .album:
            "Album"
        case let .sharedLink(baseURL, _):
            baseURL.host ?? "Shared link"
        }
    }
}
