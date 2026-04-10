//
//  ClosetStore.swift
//  PEPLOS
//

import Combine
import Foundation

@MainActor
final class ClosetStore: ObservableObject {
    /// Reserved names that must never appear in category lists (legacy / mistaken labels).
    private static let hiddenCategoryNamesLowercased: Set<String> = ["uncategorized", "ungorized"]

    @Published private(set) var categories: [ClothingCategory] = []
    @Published private(set) var items: [ClothingItem] = []

    private let v2Key = "peplos.closet.persisted.v2"
    private let legacyItemsKey = "peplos.closet.items"
    private let legacyCategoriesKey = "peplos.closet.categories"
    private let v2FileName = "closet.v2.json"
    /// One-time: recompute `photoAspectRatio` after fixing orientation-aware sizing in `ImageProcessor`.
    private let photoAspectOrientationFixKey = "peplos.migration.photoAspectOrientationFix"

    private let defaultCategoryNames = ["Tops", "Bottoms", "Shoes", "Accessories", "Outerwear"]

    /// Stable IDs for `homeCategoryShelfItems()` when no categories exist (e.g. user removed all).
    private static let fallbackHomeShelfItemUUIDs: [UUID] = [
        UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000003")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000004")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000005")!,
    ]

    init() {
        load()
    }

    static func isHiddenCategoryName(_ name: String) -> Bool {
        hiddenCategoryNamesLowercased.contains(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    /// Categories shown in UI (chips, settings, pickers). Hidden bucket names are excluded.
    var categoriesForDisplay: [ClothingCategory] {
        categories.filter { !Self.isHiddenCategoryName($0.name) }
    }

    // MARK: - Public queries

    var itemCount: Int {
        items.filter { $0.hasUploadedPhoto }.count
    }

    /// Names for pickers (default order + custom, stable).
    var allCategoryNames: [String] {
        categoriesForDisplay.map(\.name)
    }

    /// Closet chips: every category (same order as `orderedCategoriesForShelf`).
    var visibleCategoryNames: [String] {
        categoriesForDisplay.map(\.name)
    }

    /// Category summary tiles for Home “Recently Added” and Closet “All”.
    func categoryShelfItems(sortedByRecentActivity: Bool = true) -> [ClosetItem] {
        let sourceCategories = sortedByRecentActivity ? orderedCategoriesForShelf() : categories
        let visible = sourceCategories.filter { !Self.isHiddenCategoryName($0.name) }
        return visible.map { cat in
            ClosetItem.shelfTile(category: cat, coverItem: latestUploadedItem(for: cat.id))
        }
    }

    /// Home “Recently Added” strip: same as `categoryShelfItems()`, or default pastel tiles if the closet has no categories.
    func homeCategoryShelfItems() -> [ClosetItem] {
        let tiles = categoryShelfItems()
        if !tiles.isEmpty {
            return tiles
        }
        return defaultCategoryNames.enumerated().map { i, name in
            ClosetItem(
                id: Self.fallbackHomeShelfItemUUIDs[i],
                category: name,
                dateAdded: Date(timeIntervalSince1970: 0),
                thumbnailFileName: nil,
                fullImageFileName: nil,
                photoAspectRatio: nil,
                placeholderStyle: ClothingPlaceholderStyle.style(atPastelIndex: i)
            )
        }
    }

    /// Items in a single category (for Closet when a specific chip is selected).
    /// Rows with no photo are hidden as soon as that category has at least one real upload (preset tiles).
    func items(filteredBy categoryName: String) -> [ClosetItem] {
        guard let cat = categories.first(where: { $0.name == categoryName }) else {
            return []
        }
        let inCategory = items
            .filter { $0.categoryId == cat.id }
            .sorted { $0.createdAt > $1.createdAt }
        let hasPhoto = inCategory.contains { $0.hasUploadedPhoto }
        let rows = hasPhoto ? inCategory.filter { $0.hasUploadedPhoto } : inCategory
        return rows.map { ClosetItem.display(for: $0, category: cat) }
    }

    func addItem(
        categoryName: String,
        fullImageFileName: String?,
        thumbnailFileName: String?,
        originalImageFileName: String? = nil,
        importProcessingPath: ClothingImportProcessingPath? = nil
    ) {
        guard let cat = categories.first(where: { $0.name == categoryName }) else { return }
        if fullImageFileName != nil || thumbnailFileName != nil {
            items.removeAll { $0.categoryId == cat.id && !$0.hasUploadedPhoto }
        }
        let row = ClothingItem(
            categoryId: cat.id,
            imageFileName: fullImageFileName,
            thumbnailFileName: thumbnailFileName,
            originalImageFileName: originalImageFileName,
            createdAt: Date(),
            importProcessingPath: importProcessingPath
        )
        items.append(row)
        save()
    }

    /// Adds many items for one category (batch closet entry). `imageReferences` are on-disk paths from `ImageProcessor`.
    func addItems(
        categoryName: String,
        imageReferences: [(
            fullImageFileName: String,
            thumbnailFileName: String,
            photoAspectRatio: CGFloat?,
            originalImageFileName: String?,
            importProcessingPath: ClothingImportProcessingPath?
        )],
        fashionMetadata: FashionItemMetadata? = nil
    ) {
        guard let cat = categories.first(where: { $0.name == categoryName }) else { return }
        guard !imageReferences.isEmpty else { return }
        items.removeAll { $0.categoryId == cat.id && !$0.hasUploadedPhoto }
        let base = Date()
        for (i, ref) in imageReferences.enumerated() {
            let row = ClothingItem(
                categoryId: cat.id,
                imageFileName: ref.fullImageFileName,
                thumbnailFileName: ref.thumbnailFileName,
                originalImageFileName: ref.originalImageFileName,
                photoAspectRatio: ref.photoAspectRatio.map { Double($0) },
                createdAt: base.addingTimeInterval(TimeInterval(i) * 0.001),
                fashionMetadata: fashionMetadata,
                importProcessingPath: ref.importProcessingPath
            )
            items.append(row)
        }
        save()
    }

    @discardableResult
    func addCategory(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !Self.isHiddenCategoryName(trimmed) else { return nil }

        let existing = Set(categories.map { $0.name.localizedLowercase })
        guard !existing.contains(trimmed.localizedLowercase) else { return nil }

        let nextIndex = categories.count
        let pastel = nextIndex % ClothingPlaceholderStyle.paletteCount
        let created = ClothingCategory(name: trimmed, pastelStyleIndex: pastel, createdAt: Date())
        categories.append(created)
        save()
        return trimmed
    }

    func removeItem(id: UUID) {
        if let item = items.first(where: { $0.id == id }) {
            ClothingImageStorage.deleteImages(
                fullImageFileName: item.imageFileName,
                thumbnailFileName: item.thumbnailFileName,
                originalImageFileName: item.originalImageFileName
            )
        }
        items.removeAll { $0.id == id }
        save()
    }

    /// Sets or clears optional fashion metadata for a closet item (edit from Closet photo detail).
    func updateFashionMetadata(forItemId id: UUID, metadata: FashionItemMetadata?) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].fashionMetadata = metadata
        save()
    }

    /// Category display name for an item, if it still exists in the closet.
    func categoryName(forItemId id: UUID) -> String? {
        guard let item = items.first(where: { $0.id == id }),
              let cat = categories.first(where: { $0.id == item.categoryId }) else { return nil }
        return cat.name
    }

    /// Outfit order; skips IDs that no longer exist in the closet.
    func closetItems(forOutfitItemIds ids: [UUID]) -> [ClosetItem] {
        ids.compactMap { id in
            guard let item = items.first(where: { $0.id == id }),
                  let cat = categories.first(where: { $0.id == item.categoryId }) else { return nil }
            return ClosetItem.display(for: item, category: cat)
        }
    }

    /// Number of rows (including placeholders) in the category.
    func itemRowCount(inCategoryNamed name: String) -> Int {
        guard let cat = categories.first(where: { $0.name == name }) else { return 0 }
        return items.filter { $0.categoryId == cat.id }.count
    }

    func removeCategory(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let idx = categories.firstIndex(where: { $0.name == trimmed }) else { return }

        let categoryId = categories[idx].id
        deleteAllItemsAndImages(inCategoryId: categoryId)
        categories.remove(at: idx)
        save()
    }

    private func deleteAllItemsAndImages(inCategoryId categoryId: UUID) {
        for item in items where item.categoryId == categoryId {
            ClothingImageStorage.deleteImages(
                fullImageFileName: item.imageFileName,
                thumbnailFileName: item.thumbnailFileName,
                originalImageFileName: item.originalImageFileName
            )
        }
        items.removeAll { $0.categoryId == categoryId }
    }

    /// Drops hidden bucket categories and deletes their items (photos + rows).
    private func purgeHiddenCategoriesAndTheirItems() {
        let hidden = categories.filter { Self.isHiddenCategoryName($0.name) }
        guard !hidden.isEmpty else { return }
        for cat in hidden {
            deleteAllItemsAndImages(inCategoryId: cat.id)
        }
        categories.removeAll { Self.isHiddenCategoryName($0.name) }
        save()
    }

    /// Clears closet persistence, on-disk images, and reseeds default categories (factory reset).
    func resetToFactoryDefaults() {
        DurableStore.clear(fileName: v2FileName, defaultsKey: v2Key)
        UserDefaults.standard.removeObject(forKey: legacyItemsKey)
        UserDefaults.standard.removeObject(forKey: legacyCategoriesKey)
        UserDefaults.standard.removeObject(forKey: photoAspectOrientationFixKey)
        ClothingImageStorage.removeAllImageFiles()
        seedDefaultCategories()
        items = []
        save()
    }

    func moveCategory(named sourceName: String, before destinationName: String) {
        guard sourceName != destinationName,
              let sourceIndex = categories.firstIndex(where: { $0.name == sourceName }),
              let destinationIndex = categories.firstIndex(where: { $0.name == destinationName }) else {
            return
        }

        let movedCategory = categories.remove(at: sourceIndex)
        let adjustedDestination = sourceIndex < destinationIndex ? destinationIndex : destinationIndex
        categories.insert(movedCategory, at: adjustedDestination)
        save()
    }

    /// Overwrites closet metadata from a validated backup payload.
    func replaceFromBackup(categories: [ClothingCategory], items: [ClothingItem]) {
        self.categories = categories
        self.items = items
        purgeHiddenCategoriesAndTheirItems()
        save()
    }

    // MARK: - Preview / test helpers

    #if DEBUG
    /// Adds an empty “Hats” category for quick manual testing of chips + shelf sync.
    func debug_addHatsCategoryOnly() {
        _ = addCategory("Hats")
    }
    #endif

    // MARK: - Private

    private struct PersistedV2: Codable {
        var categories: [ClothingCategory]
        var items: [ClothingItem]
    }

    private func load() {
        if let decoded = DurableStore.load(PersistedV2.self, fileName: v2FileName, defaultsKey: v2Key) {
            categories = decoded.categories
            items = decoded.items
            migrateLegacyImageDataToFilesIfNeeded()
            applyPhotoAspectOrientationFixIfNeeded()
            purgeHiddenCategoriesAndTheirItems()
            return
        }

        if migrateFromLegacyIfNeeded() {
            migrateLegacyImageDataToFilesIfNeeded()
            applyPhotoAspectOrientationFixIfNeeded()
            purgeHiddenCategoriesAndTheirItems()
            save()
            return
        }

        seedDefaultCategories()
        save()
    }

    /// Moves any legacy inline `imageData` into JPEG files and clears blobs from the payload.
    private func migrateLegacyImageDataToFilesIfNeeded() {
        var changed = false
        for i in items.indices {
            guard let data = items[i].imageData, items[i].imageFileName == nil else { continue }
            do {
                let result = try ImageProcessor.processImportDataJPEGOnly(data)
                items[i].imageFileName = result.fullImageFileName
                items[i].thumbnailFileName = result.thumbnailFileName
                items[i].originalImageFileName = result.originalImageFileName
                items[i].photoAspectRatio = Double(result.photoAspectRatio)
                items[i].imageData = nil
                changed = true
            } catch {
                continue
            }
        }
        if changed { save() }
    }

    /// Clears stored aspect ratios once, then recomputes from on-disk images (uses orientation-aware `UIImage.size`).
    private func applyPhotoAspectOrientationFixIfNeeded() {
        if !UserDefaults.standard.bool(forKey: photoAspectOrientationFixKey) {
            for i in items.indices {
                items[i].photoAspectRatio = nil
            }
            UserDefaults.standard.set(true, forKey: photoAspectOrientationFixKey)
        }
        backfillPhotoAspectRatiosIfNeeded()
    }

    /// Fills `photoAspectRatio` for rows saved before that metadata existed (decode thumbnail once, then persist).
    private func backfillPhotoAspectRatiosIfNeeded() {
        var changed = false
        for i in items.indices {
            guard items[i].photoAspectRatio == nil else { continue }
            let name = items[i].thumbnailFileName ?? items[i].imageFileName
            guard let name else { continue }
            guard let img = ClothingImageStorage.uiImage(fileName: name) else { continue }
            items[i].photoAspectRatio = Double(ImageProcessor.aspectRatio(of: img))
            changed = true
        }
        if changed { save() }
    }

    private func save() {
        let payload = PersistedV2(categories: categories, items: items)
        DurableStore.save(payload, fileName: v2FileName, defaultsKey: v2Key)
    }

    private func seedDefaultCategories() {
        let cal = Calendar.current
        func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
            var c = DateComponents()
            c.year = y
            c.month = m
            c.day = day
            return cal.date(from: c) ?? Date()
        }
        let base = d(2026, 4, 3)
        categories = defaultCategoryNames.enumerated().map { i, name in
            ClothingCategory(name: name, pastelStyleIndex: i % ClothingPlaceholderStyle.paletteCount, createdAt: base)
        }
        items = []
    }

    private func orderedCategoriesForShelf() -> [ClothingCategory] {
        categories.sorted { a, b in
            let ad = latestUploadedDate(for: a.id) ?? a.createdAt
            let bd = latestUploadedDate(for: b.id) ?? b.createdAt
            if ad != bd {
                return ad > bd
            }
            return a.createdAt > b.createdAt
        }
    }

    private func latestUploadedDate(for categoryId: UUID) -> Date? {
        items
            .filter { $0.categoryId == categoryId && $0.hasUploadedPhoto }
            .map(\.createdAt)
            .max()
    }

    private func latestUploadedItem(for categoryId: UUID) -> ClothingItem? {
        items
            .filter { $0.categoryId == categoryId && $0.hasUploadedPhoto }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    // MARK: - Legacy migration

    private func migrateFromLegacyIfNeeded() -> Bool {
        let legacyItems: [LegacyClosetItem] = {
            guard let itemsData = UserDefaults.standard.data(forKey: legacyItemsKey),
                  let decoded = try? JSONDecoder().decode([LegacyClosetItem].self, from: itemsData) else {
                return []
            }
            return decoded
        }()

        var customNames: [String] = []
        if let cData = UserDefaults.standard.data(forKey: legacyCategoriesKey),
           let decoded = try? JSONDecoder().decode([String].self, from: cData) {
            customNames = decoded
        }

        if legacyItems.isEmpty && customNames.isEmpty {
            return false
        }

        var orderedNames = defaultCategoryNames + customNames
        for row in legacyItems where !orderedNames.contains(row.category) {
            orderedNames.append(row.category)
        }

        var nameToId: [String: UUID] = [:]
        var newCategories: [ClothingCategory] = []
        for (i, name) in orderedNames.enumerated() {
            let id = UUID()
            nameToId[name] = id
            newCategories.append(
                ClothingCategory(
                    id: id,
                    name: name,
                    pastelStyleIndex: i % ClothingPlaceholderStyle.paletteCount,
                    createdAt: Date()
                )
            )
        }

        var newItems: [ClothingItem] = []
        for row in legacyItems {
            guard let cid = nameToId[row.category] else { continue }
            if row.imageData != nil {
                newItems.append(
                    ClothingItem(
                        id: row.id,
                        categoryId: cid,
                        imageData: row.imageData,
                        createdAt: row.dateAdded
                    )
                )
            }
        }

        categories = newCategories
        items = newItems
        return true
    }

    /// Decodes pre–v2 persisted rows (category name + optional image; placeholder style ignored in v2).
    private struct LegacyClosetItem: Codable {
        let id: UUID
        var category: String
        var dateAdded: Date
        var imageData: Data?
        var placeholderStyle: Int
    }
}
