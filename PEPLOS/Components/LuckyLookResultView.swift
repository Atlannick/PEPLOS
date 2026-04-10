//
//  LuckyLookResultView.swift
//  PEPLOS
//

import SwiftUI

/// Full-screen Lucky Look result with minimal actions.
struct LuckyLookResultView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var closet: ClosetStore
    @EnvironmentObject private var outfitStore: OutfitStore
    @EnvironmentObject private var luckyLook: LuckyLookManager

    let snapshot: LuckyLookSnapshot

    private var showSaveOutfit: Bool {
        luckyLook.shouldShowSaveOutfit(for: snapshot)
    }

    private var luckySharePayload: OutfitSharePayload? {
        let preview = closet.outfitPreviewItems(forItemIds: snapshot.itemIds)
        guard preview.count == snapshot.itemIds.count else { return nil }
        return OutfitSharePayload(
            displayTitle: OutfitSharePayload.defaultTitle,
            previewItems: preview,
            outfitItemOrder: snapshot.itemIds
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    previewBlock

                    HStack(spacing: 12) {
                        if let luckySharePayload {
                            ShareOutfitButton(payload: luckySharePayload)
                                .frame(maxWidth: .infinity)
                        }

                        if showSaveOutfit {
                            Button {
                                let outfit = SavedOutfit(name: "Lucky Look", itemIds: snapshot.itemIds)
                                outfitStore.addOutfit(outfit)
                                luckyLook.markLuckyLookOutfitSaved(snapshotId: snapshot.id)
                            } label: {
                                Text("Save Outfit")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("Saved")
                                .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Lucky Look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var previewBlock: some View {
        let items = closet.outfitPreviewItems(forItemIds: snapshot.itemIds)
        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.75, green: 0.88, blue: 0.98),
                            Color(red: 0.55, green: 0.82, blue: 0.75),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            OutfitPreviewView(items: items, outfitItemOrder: snapshot.itemIds)
                .padding(18)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.78, contentMode: .fit)
    }
}
