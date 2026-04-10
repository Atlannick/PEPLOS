//
//  ContentView.swift
//  PEPLOS
//

import SwiftUI

struct ContentView: View {
    @StateObject private var closetStore = ClosetStore()
    @StateObject private var outfitStore = OutfitStore()
    @StateObject private var collectionService = CollectionService()
    @StateObject private var stylistWeather = StylistWeatherController()
    @StateObject private var luckyLookManager = LuckyLookManager()
    @StateObject private var appSettings = AppSettingsStore()
    @State private var selectedTab: MainTab = .home
    @State private var recoveryMessage: String?
    @State private var hasRunRecoveryCheck = false
    @State private var showFirstLaunchGuide = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .closet:
                    ClosetView()
                case .stylist:
                    StylistView()
                case .outfits:
                    OutfitsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MainTabBar(selection: $selectedTab)
        }
        .tint(AppTheme.accent)
        .environmentObject(closetStore)
        .environmentObject(outfitStore)
        .environmentObject(collectionService)
        .environmentObject(stylistWeather)
        .environmentObject(luckyLookManager)
        .environmentObject(appSettings)
        .onAppear {
            guard !hasRunRecoveryCheck else { return }
            hasRunRecoveryCheck = true
            showFirstLaunchGuide = !appSettings.hasSeenFirstLaunchGuide
            let failures = StorageRecovery.validateCorePersistenceAtLaunch()
            if !failures.isEmpty {
                recoveryMessage = failures.joined(separator: "\n")
            }
        }
        .fullScreenCover(isPresented: $showFirstLaunchGuide) {
            FirstLaunchGuideView {
                appSettings.markFirstLaunchGuideSeen()
                showFirstLaunchGuide = false
            }
        }
        .alert("Data Recovery Needed", isPresented: Binding(
            get: { recoveryMessage != nil },
            set: { if !$0 { recoveryMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(recoveryMessage ?? "Some data could not be recovered.")
        }
    }
}

#Preview {
    ContentView()
}
