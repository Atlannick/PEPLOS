//
//  OutfitPageView.swift
//  PEPLOS
//

import SwiftUI

/// Full-screen outfit page: view or edit pieces, save to collections, share, delete.
struct OutfitPageView: View {
    @EnvironmentObject private var closet: ClosetStore
    @EnvironmentObject private var outfitStore: OutfitStore
    @EnvironmentObject private var collectionService: CollectionService
    @Environment(\.dismiss) private var dismiss

    let outfit: SavedOutfit
    var onDeleteConfirmed: () -> Void

    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    @State private var isEditing = false
    @State private var draftName = ""
    @State private var savedSnapshot: SavedOutfit?
    @State private var draftItemIds: [UUID] = []
    @State private var pickingCategory: ClothingCategory?
    @State private var showSaveToCollectionSheet = false
    @State private var showSavedToast = false

    private var baseline: SavedOutfit {
        savedSnapshot ?? outfit
    }

    private var categoriesWithPhotos: [ClothingCategory] {
        closet.categoriesForDisplay.filter { !photoClosetItems(in: $0.name).isEmpty }
    }

    /// Last picked item per category (matches build-outfit semantics).
    private var itemIdByCategoryId: [UUID: UUID] {
        var m: [UUID: UUID] = [:]
        for id in draftItemIds {
            guard let row = closet.items.first(where: { $0.id == id }) else { continue }
            m[row.categoryId] = id
        }
        return m
    }

    private var rows: [ClosetItem] {
        closet.closetItems(forOutfitItemIds: draftItemIds)
    }

    private var outfitSharePayload: OutfitSharePayload? {
        let preview = closet.outfitPreviewItems(forItemIds: draftItemIds)
        guard !draftItemIds.isEmpty, preview.count == draftItemIds.count else { return nil }
        let name = isEditing ? draftName : baseline.name
        let title = OutfitSharePayload.displayTitle(outfitName: name)
        return OutfitSharePayload(
            displayTitle: title,
            previewItems: preview,
            outfitItemOrder: draftItemIds
        )
    }

    private var hasUnsavedChanges: Bool {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let itemsChanged = Set(draftItemIds) != Set(baseline.itemIds)
        return trimmed != baseline.name || itemsChanged
    }

    private var canSave: Bool {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !draftItemIds.isEmpty
    }

    private let itemGridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    /// Close control while editing (returns to `subtitleGray` after save / when not editing).
    private static let pastelRedClose = Color(red: 0.91, green: 0.55, blue: 0.56)

    var body: some View {
        ZStack(alignment: .top) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if rows.isEmpty {
                            Text(isEditing ? "Add pieces below or pick a category." : "No pieces in this outfit.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtitleGray)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        } else {
                            LazyVGrid(columns: itemGridColumns, alignment: .leading, spacing: 16) {
                                ForEach(rows) { item in
                                    largeItemBlock(item)
                                }
                            }
                        }

                        if !isEditing {
                            viewingOutfitActions
                        }

                        if isEditing {
                            editCategoriesSection
                        }

                        if isEditing {
                            deleteSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .background(AppTheme.background.ignoresSafeArea())
                .navigationTitle(isEditing ? "" : baseline.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if isEditing {
                            Button("Save") { saveEdits() }
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.green)
                                .disabled(!canSave)
                        } else {
                            Button("Edit") { isEditing = true }
                                .fontWeight(.semibold)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            closeTapped()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(isEditing ? Self.pastelRedClose : AppTheme.subtitleGray)
                        }
                        .accessibilityLabel("Close")
                    }
                    if isEditing {
                        ToolbarItem(placement: .principal) {
                            TextField("Outfit name", text: $draftName)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .sheet(item: $pickingCategory) { category in
                    CategoryItemPickerSheet(
                        category: category,
                        items: photoClosetItems(in: category.name),
                        onPick: { itemId in
                            applyPick(categoryId: category.id, itemId: itemId)
                            pickingCategory = nil
                        }
                    )
                }
                .sheet(isPresented: $showSaveToCollectionSheet) {
                    SaveToCollectionSheet(outfitId: outfit.id) {
                        showSavedToast = true
                    }
                    .environmentObject(collectionService)
                }
                .confirmationDialog(
                    "Delete this outfit?",
                    isPresented: $confirmDelete,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        collectionService.removeOutfitFromAllCollections(outfit.id)
                        onDeleteConfirmed()
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This can't be undone.")
                }
                .alert("Discard changes?", isPresented: $confirmDiscard) {
                    Button("Discard", role: .destructive) {
                        dismiss()
                    }
                    Button("Keep editing", role: .cancel) {}
                } message: {
                    Text("Your changes won't be saved.")
                }
                .task(id: outfit.id) {
                    syncFromOutfitParameter()
                }
                .onChange(of: closet.categories.map(\.id)) { _, _ in
                    pruneDraftItemsIfEditing()
                }
                .onChange(of: closet.itemCount) { _, _ in
                    pruneDraftItemsIfEditing()
                }
            }

            if showSavedToast {
                Text("Saved to Collection")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSavedToast)
        .onChange(of: showSavedToast) { _, on in
            guard on else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                await MainActor.run {
                    showSavedToast = false
                }
            }
        }
    }

    /// Bottom actions when viewing (not editing): Add to collection, Share, Delete.
    private var viewingOutfitActions: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    showSaveToCollectionSheet = true
                } label: {
                    Text("Add to a Collection")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)

                Group {
                    if let payload = outfitSharePayload {
                        ShareOutfitButton(payload: payload)
                            .frame(maxWidth: .infinity)
                    } else {
                        Button {
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body.weight(.semibold))
                                Text("Share")
                                    .font(.body.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .disabled(true)
                        .opacity(0.42)
                    }
                }
            }

            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Delete outfit", systemImage: "trash")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.outfitPink)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private var editCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add or replace pieces")
                .font(.headline.weight(.semibold))

            if categoriesWithPhotos.isEmpty {
                Text("Add photos to your closet to include items.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subtitleGray)
            } else {
                ForEach(categoriesWithPhotos) { category in
                    editCategoryRow(category)
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func editCategoryRow(_ category: ClothingCategory) -> some View {
        let style = ClothingPlaceholderStyle.style(atPastelIndex: category.pastelStyleIndex)
        let selectedId = itemIdByCategoryId[category.id]

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                categoryThumbnail(category: category, selectedItemId: selectedId, style: style)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.headline.weight(.semibold))
                    Text(selectedId == nil ? "Optional — tap Choose to add" : "In this outfit")
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
                    Button("Remove") {
                        removeItems(inCategoryId: category.id)
                    }
                    .buttonStyle(.bordered)
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

    private func largeItemBlock(_ item: ClosetItem) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text(item.category)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.subtitleGray)
                    .lineLimit(1)

                Group {
                    if let full = item.fullImageFileName {
                        AsyncImage(url: ClothingImageStorage.fileURL(fileName: full)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            case .empty:
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(AppTheme.chipInactive)
                                    .frame(maxHeight: 180)
                                    .overlay { ProgressView() }
                            case .failure:
                                ClothingPlaceholderImage(style: item.placeholderStyle, cornerRadius: 20)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(0.85, contentMode: .fit)
                                    .frame(maxHeight: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else if let thumb = item.thumbnailFileName {
                        AsyncImage(url: ClothingImageStorage.fileURL(fileName: thumb)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            case .empty, .failure:
                                ClothingPlaceholderImage(style: item.placeholderStyle, cornerRadius: 20)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(0.85, contentMode: .fit)
                                    .frame(maxHeight: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        ClothingPlaceholderImage(style: item.placeholderStyle, cornerRadius: 20)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(0.85, contentMode: .fit)
                            .frame(maxHeight: 200)
                    }
                }
                .frame(maxWidth: .infinity)
                .pepSubtleShadow()
            }

            if isEditing {
                Button {
                    removeDraftItem(item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.black.opacity(0.55))
                }
                .padding(8)
                .accessibilityLabel("Remove from outfit")
            }
        }
    }

    private var deleteSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.top, 8)

            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Delete outfit", systemImage: "trash")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.outfitPink)
        }
        .padding(.top, 8)
    }

    private func photoClosetItems(in categoryName: String) -> [ClosetItem] {
        closet.items(filteredBy: categoryName).filter { $0.hasPhoto }
    }

    private func syncFromOutfitParameter() {
        savedSnapshot = outfit
        draftName = outfit.name
        draftItemIds = outfit.itemIds.filter { id in
            guard let row = closet.items.first(where: { $0.id == id }) else { return false }
            return row.hasUploadedPhoto
        }
        isEditing = false
    }

    private func applyPick(categoryId: UUID, itemId: UUID) {
        draftItemIds.removeAll { id in
            closet.items.first(where: { $0.id == id })?.categoryId == categoryId
        }
        draftItemIds.append(itemId)
    }

    private func removeItems(inCategoryId categoryId: UUID) {
        draftItemIds.removeAll { id in
            closet.items.first(where: { $0.id == id })?.categoryId == categoryId
        }
    }

    private func removeDraftItem(_ id: UUID) {
        draftItemIds.removeAll { $0 == id }
    }

    private func pruneDraftItemsIfEditing() {
        guard isEditing else { return }
        draftItemIds.removeAll { id in
            guard let row = closet.items.first(where: { $0.id == id }) else { return true }
            if !row.hasUploadedPhoto { return true }
            guard let cat = closet.categories.first(where: { $0.id == row.categoryId }) else { return true }
            return photoClosetItems(in: cat.name).isEmpty
        }
    }

    private func saveEdits() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !draftItemIds.isEmpty else { return }
        let updated = SavedOutfit(id: outfit.id, name: trimmed, itemIds: draftItemIds)
        outfitStore.updateOutfit(updated)
        savedSnapshot = updated
        isEditing = false
    }

    private func closeTapped() {
        if isEditing && hasUnsavedChanges {
            confirmDiscard = true
        } else {
            dismiss()
        }
    }
}

#Preview {
    OutfitPageView(
        outfit: SavedOutfit(name: "Weekend", itemIds: []),
        onDeleteConfirmed: {}
    )
    .environmentObject(ClosetStore())
    .environmentObject(OutfitStore())
    .environmentObject(CollectionService())
}
