//
//  CollectionOutfitsView.swift
//  PEPLOS
//

import SwiftUI

/// Outfits saved in a single collection (same outfit may appear in multiple collections elsewhere).
struct CollectionOutfitsView: View {
    @EnvironmentObject private var closet: ClosetStore
    @EnvironmentObject private var outfitStore: OutfitStore
    @EnvironmentObject private var collectionService: CollectionService
    @Environment(\.dismiss) private var dismiss

    let collection: CollectionModel

    @State private var expandedOutfit: SavedOutfit?
    @State private var confirmDeleteCollection = false
    @State private var outfitPendingRemoveFromCollection: SavedOutfit?
    @State private var confirmRemoveFromCollection = false

    private var outfits: [SavedOutfit] {
        collectionService.savedOutfits(inCollectionId: collection.id, from: outfitStore)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if outfits.isEmpty {
                    PepEmptyState(systemImage: "tshirt", message: "No outfits in this collection yet")
                        .padding(.top, 48)
                        .padding(.bottom, 24)
                } else {
                    OutfitTwoColumnMasonryLayout(horizontalSpacing: 14, verticalSpacing: 14) {
                        ForEach(outfits) { outfit in
                            ZStack(alignment: .topLeading) {
                                Button {
                                    expandedOutfit = outfit
                                } label: {
                                    OutfitCard(
                                        outfit: outfit,
                                        showThumbnails: true,
                                        onTap: nil
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    outfitPendingRemoveFromCollection = outfit
                                    confirmRemoveFromCollection = true
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.black.opacity(0.45))
                                }
                                .buttonStyle(.plain)
                                .padding(10)
                                .accessibilityLabel("Remove from collection")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    confirmDeleteCollection = true
                } label: {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                }
                .tint(.red)
                .accessibilityLabel("Delete collection")
            }
        }
        .confirmationDialog(
            "Delete this collection?",
            isPresented: $confirmDeleteCollection,
            titleVisibility: .visible
        ) {
            Button("Delete collection", role: .destructive) {
                collectionService.deleteCollection(id: collection.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Outfits stay in your wardrobe; only this group is removed.")
        }
        .confirmationDialog(
            "Remove from this collection?",
            isPresented: $confirmRemoveFromCollection,
            titleVisibility: .visible
        ) {
            Button("Remove from collection", role: .destructive) {
                if let o = outfitPendingRemoveFromCollection {
                    collectionService.removeOutfit(o.id, fromCollectionId: collection.id)
                }
                outfitPendingRemoveFromCollection = nil
            }
            Button("Cancel", role: .cancel) {
                outfitPendingRemoveFromCollection = nil
            }
        } message: {
            Text("This will only remove the outfit from this collection. Your outfit stays saved in Outfits.")
        }
        .fullScreenCover(item: $expandedOutfit, onDismiss: { expandedOutfit = nil }) { outfit in
            OutfitPageView(
                outfit: outfit,
                onDeleteConfirmed: { outfitStore.removeOutfit(id: outfit.id) }
            )
            .environmentObject(closet)
            .environmentObject(outfitStore)
            .environmentObject(collectionService)
        }
    }
}

#Preview {
    NavigationStack {
        CollectionOutfitsView(collection: CollectionModel(name: "Weekend"))
            .environmentObject(ClosetStore())
            .environmentObject(OutfitStore())
            .environmentObject(CollectionService())
    }
}
