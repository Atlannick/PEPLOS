//
//  HomeView.swift
//  PEPLOS
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var closet: ClosetStore
    @EnvironmentObject private var outfitStore: OutfitStore
    @EnvironmentObject private var collectionService: CollectionService
    @EnvironmentObject private var stylistWeather: StylistWeatherController
    @EnvironmentObject private var luckyLook: LuckyLookManager

    @State private var showAddItem = false
    @State private var showBuildOutfit = false
    @State private var photoDetailItem: ClosetItem?
    @State private var expandedOutfit: SavedOutfit?
    @State private var isLoadingLuckyLook = false
    @State private var luckyLookSheet: LuckyLookSnapshot?
    @State private var luckyLookAlert: String?
    @State private var luckyLookTask: Task<Void, Never>?

    /// One card per category from shared store (photo or pastel placeholder).
    private var recentlyAddedCategoryCards: [ClosetItem] {
        closet.homeCategoryShelfItems()
    }

    private var emptyOutfitsState: some View {
        PepEmptyState(systemImage: "heart", message: "No outfit created yet")
            .padding(.vertical, 20)
    }

    private var hasClothingItems: Bool {
        closet.itemCount > 0
    }

    private func requestLuckyLook() {
        stylistWeather.startIfNeeded()
        isLoadingLuckyLook = true
        luckyLookTask?.cancel()
        luckyLookTask = Task { @MainActor in
            let ctx = luckyLook.makeEvaluationContext(weather: stylistWeather)
            switch luckyLook.generateLuckyLook(closet: closet, context: ctx) {
            case .success(let generation):
                luckyLook.persist(generation)
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else {
                    isLoadingLuckyLook = false
                    return
                }
                if let snap = luckyLook.activeSnapshot {
                    luckyLookSheet = snap
                }
            case .failure(let err):
                luckyLookAlert = err.localizedDescription
            }
            isLoadingLuckyLook = false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Spacer(minLength: 0)
                    HomeWeatherChip()
                    Spacer(minLength: 0)
                }

                HomeSummaryCard(
                    totalItems: closet.itemCount,
                    onAddItem: { showAddItem = true },
                    onBuildOutfit: { showBuildOutfit = true }
                )

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Recently Added", showSeeAll: false)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(recentlyAddedCategoryCards) { item in
                                ClothingCard(item: item, fixedWidth: 132)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        guard item.hasPhoto else { return }
                                        photoDetailItem = item
                                    }
                            }
                        }
                        .padding(.trailing, 4)
                    }
                }

                LuckyLookHomeSection(
                    hasClothingItems: hasClothingItems,
                    snapshot: luckyLook.activeSnapshot,
                    canGenerateNew: luckyLook.canGenerateNewLuckyLook(),
                    isLoading: isLoadingLuckyLook,
                    onRequestLuckyLook: requestLuckyLook,
                    onOpenLuckyLook: {
                        if let s = luckyLook.activeSnapshot {
                            luckyLookSheet = s
                        }
                    },
                    onAddItem: { showAddItem = true }
                )

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Your Outfits", showSeeAll: false)

                    if outfitStore.outfits.isEmpty {
                        emptyOutfitsState
                    } else {
                        OutfitTwoColumnMasonryLayout(horizontalSpacing: 14, verticalSpacing: 14) {
                            ForEach(outfitStore.outfits) { outfit in
                                OutfitCard(outfit: outfit, onTap: { expandedOutfit = outfit })
                            }
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
        .onAppear {
            stylistWeather.startIfNeeded()
            luckyLook.refreshSnapshot(closet: closet)
        }
        .onDisappear {
            luckyLookTask?.cancel()
            luckyLookTask = nil
        }
        .alert("Lucky Look", isPresented: Binding(
            get: { luckyLookAlert != nil },
            set: { if !$0 { luckyLookAlert = nil } }
        )) {
            Button("OK", role: .cancel) { luckyLookAlert = nil }
        } message: {
            Text(luckyLookAlert ?? "")
        }
        .fullScreenCover(isPresented: $showAddItem) {
            AddItemView()
                .environmentObject(closet)
        }
        .fullScreenCover(isPresented: $showBuildOutfit) {
            BuildOutfitView()
                .environmentObject(closet)
                .environmentObject(outfitStore)
        }
        .fullScreenCover(item: $photoDetailItem, onDismiss: { photoDetailItem = nil }) { item in
            ClothingPhotoDetailView(item: item)
                .environmentObject(closet)
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
        .fullScreenCover(item: $luckyLookSheet, onDismiss: { luckyLookSheet = nil }) { snap in
            LuckyLookResultView(snapshot: snap)
                .environmentObject(closet)
                .environmentObject(outfitStore)
                .environmentObject(luckyLook)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ClosetStore())
        .environmentObject(OutfitStore())
        .environmentObject(CollectionService())
        .environmentObject(StylistWeatherController())
        .environmentObject(LuckyLookManager())
}
