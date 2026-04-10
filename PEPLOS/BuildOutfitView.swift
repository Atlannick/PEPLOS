//
//  BuildOutfitView.swift
//  PEPLOS
//

import SwiftUI

struct BuildOutfitView: View {
    @EnvironmentObject private var closet: ClosetStore
    @EnvironmentObject private var outfitStore: OutfitStore
    @Environment(\.dismiss) private var dismiss

    /// Category id → chosen closet item id (at most one per category).
    @State private var selectedItemByCategory: [UUID: UUID] = [:]
    @State private var pickingCategory: ClothingCategory?
    @State private var showNameSheet = false

    private var categoriesWithPhotos: [ClothingCategory] {
        closet.categoriesForDisplay.filter { !photoClosetItems(in: $0.name).isEmpty }
    }

    private var selectedItemIds: [UUID] {
        categoriesWithPhotos.compactMap { selectedItemByCategory[$0.id] }
    }

    private var canCreateOutfit: Bool {
        !selectedItemIds.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if categoriesWithPhotos.isEmpty {
                    PepEmptyState(systemImage: "photo", message: "Add photos to your closet to build an outfit")
                        .padding(.top, 48)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose one item from each category you want. You only need one pick to create an outfit.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtitleGray)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(categoriesWithPhotos) { category in
                                categoryRow(category)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)

                    createOutfitBar
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Build outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { pruneSelections() }
            .onChange(of: closet.categories.map(\.id)) { _, _ in
                pruneSelections()
            }
            .onChange(of: closet.itemCount) { _, _ in
                pruneSelections()
            }
            .sheet(item: $pickingCategory) { category in
                CategoryItemPickerSheet(
                    category: category,
                    items: photoClosetItems(in: category.name),
                    onPick: { itemId in
                        selectedItemByCategory[category.id] = itemId
                        pickingCategory = nil
                    }
                )
            }
            .sheet(isPresented: $showNameSheet) {
                NameOutfitSheet(
                    onCancel: { showNameSheet = false },
                    onSave: { name in
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let outfit = SavedOutfit(name: trimmed, itemIds: selectedItemIds)
                        outfitStore.addOutfit(outfit)
                        showNameSheet = false
                        dismiss()
                    }
                )
            }
        }
    }

    private var createOutfitBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                showNameSheet = true
            } label: {
                Text("Create outfit")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canCreateOutfit ? .white : AppTheme.subtitleGray)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(canCreateOutfit ? AppTheme.accent : AppTheme.chipInactive)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .disabled(!canCreateOutfit)
        }
        .background(AppTheme.cardBackground)
    }

    @ViewBuilder
    private func categoryRow(_ category: ClothingCategory) -> some View {
        let style = ClothingPlaceholderStyle.style(atPastelIndex: category.pastelStyleIndex)
        let selectedId = selectedItemByCategory[category.id]

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                categoryThumbnail(category: category, selectedItemId: selectedId, style: style)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.headline.weight(.semibold))
                    Text(selectedId == nil ? "Optional — tap Choose to add" : "Selected")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtitleGray)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                if selectedId == nil {
                    Button("Choose") { pickingCategory = category }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                } else {
                    Button("Change") { pickingCategory = category }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .pepCardShadow()
    }

    @ViewBuilder
    private func categoryThumbnail(
        category: ClothingCategory,
        selectedItemId: UUID?,
        style: ClothingPlaceholderStyle
    ) -> some View {
        if let id = selectedItemId,
           let name = closet.items.first(where: { $0.id == id })?.thumbnailFileName {
            let url = ClothingImageStorage.fileURL(fileName: name)
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.chipInactive)
                        image
                            .resizable()
                            .scaledToFit()
                    }
                    .frame(width: 56, height: 56)
                    .clipped()
                case .empty:
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.chipInactive)
                        .frame(width: 56, height: 56)
                        .overlay { ProgressView().controlSize(.small) }
                case .failure:
                    ClothingPlaceholderImage(style: style, cornerRadius: 14)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            ClothingPlaceholderImage(style: style, cornerRadius: 14)
        }
    }

    private func photoClosetItems(in categoryName: String) -> [ClosetItem] {
        closet.items(filteredBy: categoryName).filter { $0.hasPhoto }
    }

    private func pruneSelections() {
        let allowed = Set(categoriesWithPhotos.map(\.id))
        var next = selectedItemByCategory.filter { allowed.contains($0.key) }
        for (catId, itemId) in next {
            if closet.items.first(where: { $0.id == itemId })?.hasUploadedPhoto != true {
                next.removeValue(forKey: catId)
            }
        }
        selectedItemByCategory = next
    }
}

// MARK: - Name outfit

private struct NameOutfitSheet: View {
    var onCancel: () -> Void
    var onSave: (String) -> Void

    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Name this outfit")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtitleGray)

                TextField("Outfit name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { saveIfValid() }

                Spacer()
            }
            .padding(20)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Save outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveIfValid() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                nameFocused = true
            }
        }
    }

    private func saveIfValid() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
    }
}

#Preview {
    BuildOutfitView()
        .environmentObject(ClosetStore())
        .environmentObject(OutfitStore())
}
