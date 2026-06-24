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
        Form {
            Picker("Source type", selection: $kind) {
                Text("Album").tag(Kind.album)
                Text("Shared link").tag(Kind.sharedLink)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("onboarding.source.type")

            if let errorMessage = sourceLibrary.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("onboarding.source.error")
                }
            }

            switch kind {
            case .album:
                AlbumPickerSection(onboarding: onboarding, sourceLibrary: sourceLibrary)
            case .sharedLink:
                SharedLinkSection(sourceLibrary: sourceLibrary)
            }

            if !sourceLibrary.sources.isEmpty {
                Section {
                    ForEach(sourceLibrary.sources) { source in
                        HStack {
                            Image(systemName: source.kind.onboardingIconName)
                                .foregroundStyle(.secondary)
                            Text(source.label)
                            Spacer()
                            if source.id == sourceLibrary.activeID {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                        .accessibilityIdentifier("onboarding.source.added.\(source.id)")
                    }
                } header: {
                    Text("Added sources")
                }

                Section {
                    Button {
                        onboarding.proceedToConfirm()
                    } label: {
                        Text("Continue")
                    }
                    .accessibilityIdentifier("onboarding.source.continue")
                }
            }
        }
        .navigationTitle("Add a source")
        .task { await onboarding.loadAlbumsIfNeeded() }
    }
}

/// Lists the connected server's albums (already fetched during the connection step);
/// tapping one adds it to the library. Albums already added show a checkmark.
private struct AlbumPickerSection: View {
    @Bindable var onboarding: OnboardingViewModel
    @Bindable var sourceLibrary: SourceLibraryViewModel

    var body: some View {
        Section {
            if onboarding.albums.isEmpty {
                Label("No albums on this server. Add a shared link instead.", systemImage: "photo.on.rectangle")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(onboarding.albums, id: \.id) { album in
                    let label = album.name.isEmpty ? album.id : album.name
                    let isAdded = sourceLibrary.sources.contains { $0.label == label }
                    Button {
                        sourceLibrary.addAlbumSource(albumID: album.id, label: label)
                    } label: {
                        HStack {
                            Text(label)
                            Spacer()
                            if isAdded {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .disabled(isAdded)
                    .accessibilityIdentifier("onboarding.album.\(album.id)")
                }
            }
        } header: {
            Text("Choose an album")
        }
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
