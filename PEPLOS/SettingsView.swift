//
//  SettingsView.swift
//  PEPLOS
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var closet: ClosetStore
    @EnvironmentObject private var outfitStore: OutfitStore
    @EnvironmentObject private var collectionService: CollectionService
    @EnvironmentObject private var luckyLook: LuckyLookManager
    @EnvironmentObject private var appSettings: AppSettingsStore
    @EnvironmentObject private var stylistWeather: StylistWeatherController
    @State private var showResetConfirm = false
    @State private var showImportConfirm = false
    @State private var showImportLocationGuide = false
    @State private var showImportPicker = false
    @State private var isPrivacyPolicyExpanded = false
    @State private var exportFileURL: URL?
    @State private var pendingImportFileURL: URL?
    @State private var backupAlertMessage: String?
    @State private var lastExportText = BackupService.lastExportText()
    @FocusState private var isNameFieldFocused: Bool
    /// Edited values; committed to `AppSettingsStore` only when the user taps Save.
    @State private var draftUserName = ""
    @State private var draftGender = UserGender.male
    @State private var draftTemperature = TemperatureUnit.celsius
    /// Snapshot when settings were last loaded or saved (used to decide if weather should refresh on Save).
    @State private var baselineTemperature = TemperatureUnit.celsius

    private var hasUnsavedChanges: Bool {
        draftUserName != appSettings.userName
            || draftGender != appSettings.gender
            || draftTemperature != appSettings.temperatureUnit
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                TopScreenBar(
                    title: nil,
                    titleGradientColors: AppTheme.screenHeaderTitleGradientColors,
                    titlePointSize: 28,
                    trailingActionTitle: hasUnsavedChanges ? "Save" : nil,
                    onTrailingAction: applySave,
                    trailingActionUsesGreenAccent: true,
                    showsAddButton: false
                )

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Profile", showSeeAll: false)

                    SettingsSectionCard {
                        VStack(alignment: .leading, spacing: 18) {
                            TextField("Name", text: $draftUserName)
                                .textContentType(.name)
                                .textInputAutocapitalization(.words)
                                .focused($isNameFieldFocused)
                                .submitLabel(.done)
                                .textFieldStyle(.roundedBorder)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Gender")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primary.opacity(0.78))

                                Picker("Gender", selection: $draftGender) {
                                    ForEach(UserGender.allCases) { g in
                                        Text(g.displayName).tag(g)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Closet Stats", showSeeAll: false)

                    SettingsSectionCard {
                        ClosetStatsView(
                            totalItems: closet.itemCount,
                            totalSavedOutfits: outfitStore.outfits.count,
                            totalCategories: closet.categoriesForDisplay.count
                        )
                    }
                }

#if DEBUG
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Import paths (debug)", showSeeAll: false)

                    SettingsSectionCard {
                        ClosetImportPathSummaryDebugView(items: closet.items)
                    }
                }
#endif

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Lucky Look", showSeeAll: false)

                    SettingsSectionCard {
                        luckyLookStatusText
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary.opacity(0.78))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Style Preference", showSeeAll: false)

                    SettingsSectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Style Preference", selection: Binding(
                                get: { appSettings.stylePreference },
                                set: { appSettings.setStylePreference($0) }
                            )) {
                                ForEach(PeplosStylePreference.allCases) { p in
                                    Text(p.displayName).tag(p)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Favorite Colors", showSeeAll: false)

                    SettingsSectionCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tap to select favorites")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.subtitleGray)
                            FavoriteColorPickerView(appSettings: appSettings)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Units", showSeeAll: false)

                    SettingsSectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Temperature")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.primary.opacity(0.78))

                            Picker("Temperature", selection: $draftTemperature) {
                                ForEach(TemperatureUnit.allCases) { u in
                                    Text(u.displayName).tag(u)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "About", showSeeAll: false)

                    SettingsSectionCard {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Version")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.primary.opacity(0.72))
                                Spacer()
                                Text(PeplosAppVersion.marketingAndBuild)
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Color.primary.opacity(0.88))
                            }
                            Divider().opacity(0.35).padding(.vertical, 14)
                            aboutLinkRow(title: "Send Feedback", url: Self.feedbackMailURL)
                            Divider().opacity(0.35).padding(.vertical, 14)
                            privacyPolicySection
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Data & Backup", showSeeAll: false)

                    SettingsSectionCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Your data is stored on this device and may be included in normal iPhone backup. You can also export a manual backup to Files or iCloud Drive.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtitleGray)

                            VStack(spacing: 10) {
                                backupInfoRow(title: "Local Data", value: "On This iPhone")
                                backupInfoRow(title: "Device Backup", value: "Supported")
                                backupInfoRow(title: "Manual Backup", value: "Available")
                                backupInfoRow(title: "Last Backup Exported", value: lastExportText)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    exportBackup()
                                } label: {
                                    Label("Export Backup", systemImage: "square.and.arrow.up")
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 52)
                                        .padding(.horizontal, 8)
                                        .background(AppTheme.background)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .strokeBorder(AppTheme.accent.opacity(0.32), lineWidth: 1)
                                        }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppTheme.accent)

                                Button {
                                    showImportLocationGuide = true
                                } label: {
                                    Label("Import Backup", systemImage: "tray.and.arrow.down")
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 52)
                                        .padding(.horizontal, 8)
                                        .background(AppTheme.background)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .strokeBorder(AppTheme.accent.opacity(0.32), lineWidth: 1)
                                        }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Data", showSeeAll: false)

                    SettingsSectionCard {
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Text("Reset App")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.plain)
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
            reloadDraftFromAppSettings()
        }
        .onDisappear {
            reloadDraftFromAppSettings()
        }
        .alert("Reset Peplos?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                performReset()
            }
        } message: {
            Text("This will permanently remove your local data from this device. Consider exporting a backup first. This action cannot be undone.")
        }
        .alert("Import Backup?", isPresented: $showImportConfirm) {
            Button("Cancel", role: .cancel) {
                pendingImportFileURL = nil
            }
            Button("Continue") {
                performConfirmedImport()
            }
        } message: {
            Text("Importing this backup will replace your current data on this device. A safety backup of your current data will be created before import.")
        }
        .alert("Choose Backup Location", isPresented: $showImportLocationGuide) {
            Button("Cancel", role: .cancel) {}
            Button("Open Picker") {
                showImportPicker = true
            }
        } message: {
            Text("Import a backup file from Files or iCloud Drive. If needed, tap Browse at the bottom to choose the location.")
        }
        .alert("Backup", isPresented: Binding(
            get: { backupAlertMessage != nil },
            set: { if !$0 { backupAlertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupAlertMessage ?? "")
        }
        .sheet(item: Binding(
            get: { exportFileURL.map(ExportShareFile.init(url:)) },
            set: { _ in exportFileURL = nil }
        )) { item in
            ShareSheet(activityItems: [item.url]) { completed, _ in
                guard completed else { return }
                BackupService.markExportCompleted()
                refreshBackupTimestamps()
            }
        }
        .sheet(isPresented: $showImportPicker) {
            BackupDocumentPicker(
                allowedContentTypes: [.item, .data, .json, UTType(filenameExtension: BackupFormat.fileExtension) ?? .data],
                onCancel: {
                    backupAlertMessage = "Import canceled or failed."
                },
                onPick: { url in
                    handlePickedImportURL(url)
                }
            )
        }
    }

    private var luckyLookStatusText: Text {
        Text("Outfits created by Lucky Look: \(luckyLook.totalGeneratedLooks())")
    }

    private static var feedbackMailURL: URL? {
        URL(string: "mailto:feedback@peplos.app?subject=Peplos%20Feedback")
    }

    @ViewBuilder
    private func aboutLinkRow(title: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                HStack {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent.opacity(0.7))
                }
            }
        } else {
            aboutPlaceholderRow(title: title, subtitle: nil)
        }
    }

    private func aboutPlaceholderRow(title: String, subtitle: String?) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.subtitleGray)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.28))
        }
    }

    private var privacyPolicySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPrivacyPolicyExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Text("Privacy Policy")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: isPrivacyPolicyExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary.opacity(0.45))
                }
            }
            .buttonStyle(.plain)

            if isPrivacyPolicyExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Peplos respects your privacy.")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary.opacity(0.82))

                    Text("Peplos does not collect, store, transmit, or share any personal information.")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary.opacity(0.82))

                    Text("All data created in the app - including clothing photos and outfit information - is stored only on your device. The developer of Peplos does not have access to this data.")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary.opacity(0.82))

                    Text("The app may request access to certain device features such as:")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary.opacity(0.82))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Camera - to take photos of clothing items")
                        Text("• Photo Library - to select existing clothing photos")
                        Text("• Location - to display local weather information for outfit suggestions")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.primary.opacity(0.82))

                    Text("These permissions are used only to enable app functionality. No information from these features is collected or transmitted outside your device.")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary.opacity(0.82))

                    Text("If the app is deleted, all associated data stored by the app may also be removed.")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary.opacity(0.82))

                    Text("If you have questions about this policy, please contact:")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary.opacity(0.82))

                    Text("support@peplos.app")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func backupInfoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary.opacity(0.74))
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.88))
                .multilineTextAlignment(.trailing)
        }
    }

    private func applySave() {
        isNameFieldFocused = false
        commitProfileSettings()
    }

    private func reloadDraftFromAppSettings() {
        draftUserName = appSettings.userName
        draftGender = appSettings.gender
        draftTemperature = appSettings.temperatureUnit
        baselineTemperature = appSettings.temperatureUnit
        refreshBackupTimestamps()
    }

    private func commitProfileSettings() {
        appSettings.setUserName(draftUserName)
        appSettings.setGender(draftGender)
        appSettings.setTemperatureUnit(draftTemperature)
        if draftTemperature != baselineTemperature {
            stylistWeather.refreshWeatherForCurrentUnit()
        }
        baselineTemperature = draftTemperature
    }

    private func performReset() {
        PeplosDataReset.performFactoryReset(
            closet: closet,
            outfitStore: outfitStore,
            collectionService: collectionService,
            luckyLook: luckyLook,
            appSettings: appSettings
        )
        stylistWeather.refreshWeatherForCurrentUnit()
        reloadDraftFromAppSettings()
    }

    private func exportBackup() {
        do {
            // Ensure profile edits currently visible in Settings are persisted before backup export.
            if hasUnsavedChanges {
                commitProfileSettings()
            }
            exportFileURL = try BackupService.makeExportFile(
                closet: closet,
                outfitStore: outfitStore,
                collectionService: collectionService,
                appSettings: appSettings
            )
        } catch {
            backupAlertMessage = "Could not export backup. Please try again."
        }
    }

    private func handlePickedImportURL(_ url: URL) {
        do {
            let tempURL = try copyPickedBackupToTemporaryLocation(from: url)
            _ = try BackupValidator.validateAndDecodeBackup(from: tempURL)
            pendingImportFileURL = tempURL
            showImportConfirm = true
        } catch {
            backupAlertMessage = error.localizedDescription
        }
    }

    private func performConfirmedImport() {
        guard let url = pendingImportFileURL else { return }
        defer {
            pendingImportFileURL = nil
            try? FileManager.default.removeItem(at: url)
        }
        do {
            try BackupService.importBackup(
                from: url,
                closet: closet,
                outfitStore: outfitStore,
                collectionService: collectionService,
                appSettings: appSettings
            )
            stylistWeather.refreshWeatherForCurrentUnit()
            reloadDraftFromAppSettings()
            backupAlertMessage = "Backup imported successfully."
        } catch {
            backupAlertMessage = error.localizedDescription
        }
    }

    private func refreshBackupTimestamps() {
        lastExportText = BackupService.lastExportText()
    }

    private func copyPickedBackupToTemporaryLocation(from sourceURL: URL) throws -> URL {
        let didAccessSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-import.\(BackupFormat.fileExtension)")
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }

        var coordinatorError: NSError?
        var readError: Error?
        var didCopy = false
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: sourceURL, options: [.withoutChanges], error: &coordinatorError) { readableURL in
            do {
                let data = try Data(contentsOf: readableURL, options: [.mappedIfSafe])
                try data.write(to: tempURL, options: [.atomic, .completeFileProtection])
                didCopy = true
            } catch {
                readError = error
            }
        }
        // Fallback: some picker URLs are readable directly even when security-scoped access is not granted.
        if !didCopy {
            do {
                let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
                try data.write(to: tempURL, options: [.atomic, .completeFileProtection])
                didCopy = true
            } catch {
                if let readError { throw readError }
                if let coordinatorError { throw coordinatorError }
                throw ImportPreparationError.cannotAccessFile
            }
        }
        return tempURL
    }
}

private enum ImportPreparationError: LocalizedError {
    case cannotAccessFile

    var errorDescription: String? {
        switch self {
        case .cannotAccessFile:
            return "Could not access this file from Files. Please try selecting it again."
        }
    }
}

private struct ExportShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct BackupDocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onCancel: () -> Void
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCancel: onCancel, onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onCancel: () -> Void
        private let onPick: (URL) -> Void

        init(onCancel: @escaping () -> Void, onPick: @escaping (URL) -> Void) {
            self.onCancel = onCancel
            self.onPick = onPick
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let first = urls.first else {
                onCancel()
                return
            }
            onPick(first)
        }
    }
}

#if DEBUG
private struct ClosetImportPathSummaryDebugView: View {
    let items: [ClothingItem]

    /// Items with a stored path (only these count toward pipeline stats).
    private var recorded: [ClothingItem] {
        items.filter { $0.importProcessingPath != nil }
    }

    private var totalTested: Int { recorded.count }

    private func count(_ path: ClothingImportProcessingPath) -> Int {
        recorded.filter { $0.importProcessingPath == path }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Summary (persisted paths only)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.78))
            statLine("Total tested imports", "\(totalTested)")
            statLine(ClothingImportProcessingPath.pngCutout.rawValue, "\(count(.pngCutout))")
            statLine(ClothingImportProcessingPath.jpegFallbackVisionFailed.rawValue, "\(count(.jpegFallbackVisionFailed))")
            statLine(ClothingImportProcessingPath.jpegFallbackQualityFailed.rawValue, "\(count(.jpegFallbackQualityFailed))")
            statLine(ClothingImportProcessingPath.jpegFallbackUnsupportedIOS.rawValue, "\(count(.jpegFallbackUnsupportedIOS))")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.72))
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.primary.opacity(0.85))
        }
    }
}

#endif

#Preview {
    SettingsView()
        .environmentObject(ClosetStore())
        .environmentObject(OutfitStore())
        .environmentObject(CollectionService())
        .environmentObject(LuckyLookManager())
        .environmentObject(AppSettingsStore())
        .environmentObject(StylistWeatherController())
}
