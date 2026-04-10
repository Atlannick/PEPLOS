//
//  AddItemMetadataView.swift
//  PEPLOS
//
//  Optional styling details for a closet item (add from Closet, or legacy flows).
//

import SwiftUI
import UIKit

struct AddItemMetadataView: View {
    let closetShelfName: String
    let previewThumbnailFileNames: [String]
    /// When set (e.g. editing from Closet), form is prefilled and color auto-suggestion is skipped.
    var existingMetadata: FashionItemMetadata? = nil
    let onCancel: () -> Void
    let onSave: (FashionItemMetadata) -> Void
    /// When set, shows **Remove styling** to clear saved metadata (Closet editor).
    var onClear: (() -> Void)? = nil
    /// When `true`, opened from Closet (title and copy tuned for optional follow-up styling).
    var isFromCloset: Bool = false

    @State private var primaryColor: FashionColor?
    @State private var suggestedColor: FashionColor?
    @State private var isAnalyzingColor = false
    @State private var selectedSeasons: Set<FashionSeason> = []
    @State private var selectedOccasions: Set<AddItemOccasionOption> = []
    @State private var selectedStyles: Set<AddItemStyleOption> = []

    private var canSave: Bool {
        primaryColor != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !previewThumbnailFileNames.isEmpty {
                        previewStrip
                    }

                    if isFromCloset {
                        Text("Optional: add color and tags so Lucky Look can use this piece. Item role follows your closet shelf. Tap Back to leave without saving.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtitleGray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    MetadataFormCard(
                        title: "Primary color",
                        subtitle: colorSubtitle
                    ) {
                        if isAnalyzingColor {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Suggesting a color from your photo…")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtitleGray)
                            }
                            .padding(.bottom, 4)
                        }
                        FashionColorChipGrid(
                            selection: $primaryColor,
                            palette: FashionColor.addItemPalette
                        )
                    }

                    MetadataFormCard(
                        title: "Season (optional)",
                        subtitle: "Leave blank if this works year-round"
                    ) {
                        MetadataMultiSelectGrid(
                            options: FashionSeason.allCases,
                            selection: $selectedSeasons,
                            titleFor: { $0.addItemPickerTitle }
                        )
                    }

                    MetadataFormCard(
                        title: "Occasion (optional)",
                        subtitle: nil
                    ) {
                        MetadataMultiSelectGrid(
                            options: AddItemOccasionOption.allCases,
                            selection: $selectedOccasions,
                            titleFor: { $0.label }
                        )
                    }

                    MetadataFormCard(
                        title: "Style (optional)",
                        subtitle: nil
                    ) {
                        MetadataMultiSelectGrid(
                            options: AddItemStyleOption.allCases,
                            selection: $selectedStyles,
                            titleFor: { $0.label }
                        )
                    }

                    Text("Shelf: \(closetShelfName)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtitleGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    if let onClear {
                        Button(role: .destructive) {
                            onClear()
                        } label: {
                            Text("Remove styling details")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(isFromCloset ? "Styling details" : "Item details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .task {
                if let m = existingMetadata {
                    applyHydration(m)
                } else if let first = previewThumbnailFileNames.first {
                    isAnalyzingColor = true
                    let suggestion = await Self.detachedColorSuggestion(thumbnailFileName: first)
                    suggestedColor = suggestion
                    if primaryColor == nil {
                        primaryColor = suggestion
                    }
                    isAnalyzingColor = false
                }
            }
        }
    }

    private func applyHydration(_ m: FashionItemMetadata) {
        primaryColor = m.primaryColor
        selectedSeasons = m.suitableSeasons
        selectedOccasions = Set(AddItemOccasionOption.allCases.filter { m.suitableOccasions.contains($0.engineValue) })
        selectedStyles = Set(AddItemStyleOption.allCases.filter { m.styleTags.contains($0.engineValue) })
    }

    private static func detachedColorSuggestion(thumbnailFileName: String) async -> FashionColor? {
        await MainActor.run {
            guard let ui = ClothingImageStorage.uiImage(fileName: thumbnailFileName) else { return nil }
            return ImageColorAnalyzer.suggestFashionColor(from: ui)
        }
    }

    private var colorSubtitle: String? {
        if let suggestedColor, primaryColor == suggestedColor {
            return "Suggested \(suggestedColor.addItemDisplayName) — tap another swatch to change"
        }
        if suggestedColor != nil {
            return "Tap a swatch to set the main color"
        }
        return "Pick the color that best describes this piece"
    }

    @ViewBuilder
    private var previewStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(previewThumbnailFileNames.count == 1 ? "Photo" : "Photos")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.78))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(previewThumbnailFileNames.enumerated()), id: \.offset) { _, name in
                        let url = ClothingImageStorage.fileURL(fileName: name)
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(AppTheme.chipInactive)
                                    image
                                        .resizable()
                                        .scaledToFit()
                                }
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(AppTheme.searchButtonBorder, lineWidth: 1)
                                }
                            case .empty:
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppTheme.chipInactive)
                                    .frame(width: 96, height: 96)
                                    .overlay { ProgressView() }
                            case .failure:
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppTheme.chipInactive)
                                    .frame(width: 96, height: 96)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .pepCardShadow()
    }

    private func save() {
        guard let color = primaryColor else { return }
        let inferredCategory = LuckyLookCategoryInference.inferCategory(fromCategoryName: closetShelfName)
        let seasons = selectedSeasons
        let occasions = Set(selectedOccasions.map(\.engineValue))
        let tags = Set(selectedStyles.map(\.engineValue))
        let meta = FashionItemMetadataFormMapper.build(
            itemCategory: inferredCategory,
            primaryColor: color,
            seasons: seasons,
            occasions: occasions,
            styleTags: tags
        )
        onSave(meta)
    }
}

#Preview {
    AddItemMetadataView(
        closetShelfName: "Tops",
        previewThumbnailFileNames: [],
        onCancel: {},
        onSave: { _ in }
    )
}
