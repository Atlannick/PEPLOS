//
//  OutfitsView.swift
//  PEPLOS
//

import SwiftUI

struct OutfitsView: View {
    @EnvironmentObject private var closet: ClosetStore
    @EnvironmentObject private var outfitStore: OutfitStore
    @EnvironmentObject private var collectionService: CollectionService
    @State private var showBuildOutfit = false
    @State private var expandedOutfit: SavedOutfit?
    @State private var showCollectionsBrowser = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                TopScreenBar(
                    title: nil,
                    titleGradientColors: AppTheme.screenHeaderTitleGradientColors,
                    titlePointSize: 28,
                    leadingActionTitle: "Collections",
                    onLeadingAction: { showCollectionsBrowser = true },
                    onAdd: { showBuildOutfit = true }
                )

                if outfitStore.outfits.isEmpty {
                    PepEmptyState(systemImage: "heart", message: "No outfit created yet")
                        .padding(.top, 72)
                        .padding(.bottom, 32)
                } else {
                    OutfitTwoColumnMasonryLayout(horizontalSpacing: 14, verticalSpacing: 14) {
                        ForEach(outfitStore.outfits) { outfit in
                            OutfitCard(
                                outfit: outfit,
                                showThumbnails: true,
                                onTap: { expandedOutfit = outfit }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .sheet(isPresented: $showCollectionsBrowser) {
            CollectionsBrowserSheet()
                .environmentObject(collectionService)
                .environmentObject(outfitStore)
                .environmentObject(closet)
        }
        .fullScreenCover(isPresented: $showBuildOutfit) {
            BuildOutfitView()
                .environmentObject(closet)
                .environmentObject(outfitStore)
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
    OutfitsView()
        .environmentObject(ClosetStore())
        .environmentObject(OutfitStore())
        .environmentObject(CollectionService())
}
