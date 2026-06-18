//
//  AlbumStepView.swift
//  Immich Slideshow
//
//  Step 3: pick an album. Selecting one persists the configuration and finishes
//  onboarding (step -> done). An empty list shows a hint instead of a dead end.
//

import ImmichClient
import OnboardingKit
import SwiftUI

struct AlbumStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        Group {
            if viewModel.albums.isEmpty {
                ContentUnavailableView {
                    Label("Keine Alben", systemImage: "photo.on.rectangle")
                } description: {
                    Text(viewModel.errorMessage ?? "Lege in Immich ein Album an und versuche es erneut.")
                }
            } else {
                List(viewModel.albums, id: \.id) { album in
                    Button {
                        Task { await viewModel.selectAlbum(id: album.id) }
                    } label: {
                        HStack {
                            Text(album.name.isEmpty ? album.id : album.name)
                            Spacer()
                            if viewModel.selectedAlbumID == album.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .disabled(viewModel.isBusy)
                }
            }
        }
        .navigationTitle("Album wählen")
    }
}
