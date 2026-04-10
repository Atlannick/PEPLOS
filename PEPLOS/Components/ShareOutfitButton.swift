//
//  ShareOutfitButton.swift
//  PEPLOS
//

import SwiftUI
import UIKit

/// Primary action to render `OutfitShareCardView` and open the system share sheet.
struct ShareOutfitButton: View {
    var payload: OutfitSharePayload

    @State private var isPreparing = false
    @State private var shareImage: UIImage?
    @State private var showSheet = false
    @State private var showRenderFailed = false

    var body: some View {
        Button {
            Task { await prepareAndShare() }
        } label: {
            HStack(spacing: 8) {
                if isPreparing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                }
                Text("Share")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppTheme.accent)
        .disabled(isPreparing)
        .sheet(isPresented: $showSheet, onDismiss: { shareImage = nil }) {
            if let shareImage {
                ShareSheet(activityItems: [shareImage])
            }
        }
        .alert("Couldn't share right now", isPresented: $showRenderFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again in a moment.")
        }
    }

    @MainActor
    private func prepareAndShare() async {
        guard !isPreparing else { return }
        isPreparing = true
        defer { isPreparing = false }

        // Give SwiftUI one turn to settle before snapshotting.
        await Task.yield()

        let card = OutfitShareCardView(payload: payload)
        let size = OutfitShareCardView.exportSize
        let image = ShareRenderer.renderToImage(card, size: size, scale: 1)

        guard let image else {
            showRenderFailed = true
            return
        }
        shareImage = image
        showSheet = true
    }
}
