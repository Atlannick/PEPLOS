//
//  ClosetItem.swift
//  PEPLOS
//

import Foundation

/// Display model for `ClothingCard` and category summary tiles (not persisted — built from `ClothingCategory` + optional `ClothingItem`).
struct ClosetItem: Identifiable, Hashable {
    let id: UUID
    var category: String
    var dateAdded: Date
    var thumbnailFileName: String?
    var fullImageFileName: String?
    var placeholderStyle: ClothingPlaceholderStyle
    /// Width ÷ height when known (`nil` for legacy items).
    var photoAspectRatio: CGFloat?

    init(
        id: UUID = UUID(),
        category: String,
        dateAdded: Date = Date(),
        thumbnailFileName: String? = nil,
        fullImageFileName: String? = nil,
        photoAspectRatio: CGFloat? = nil,
        placeholderStyle: ClothingPlaceholderStyle
    ) {
        self.id = id
        self.category = category
        self.dateAdded = dateAdded
        self.thumbnailFileName = thumbnailFileName
        self.fullImageFileName = fullImageFileName
        self.photoAspectRatio = photoAspectRatio
        self.placeholderStyle = placeholderStyle
    }

    var hasPhoto: Bool {
        thumbnailFileName != nil || fullImageFileName != nil
    }

    /// Row for a persisted item inside a category list.
    static func display(for item: ClothingItem, category: ClothingCategory) -> ClosetItem {
        let style = ClothingPlaceholderStyle.style(atPastelIndex: category.pastelStyleIndex)
        return ClosetItem(
            id: item.id,
            category: category.name,
            dateAdded: item.createdAt,
            thumbnailFileName: item.thumbnailFileName,
            fullImageFileName: item.imageFileName,
            photoAspectRatio: item.photoAspectRatio.map { CGFloat($0) },
            placeholderStyle: style
        )
    }

    /// One tile per category: latest uploaded image, or the category’s pastel placeholder when empty.
    static func shelfTile(category: ClothingCategory, coverItem: ClothingItem?) -> ClosetItem {
        let style = ClothingPlaceholderStyle.style(atPastelIndex: category.pastelStyleIndex)
        if let cover = coverItem {
            return ClosetItem(
                id: cover.id,
                category: category.name,
                dateAdded: cover.createdAt,
                thumbnailFileName: cover.thumbnailFileName,
                fullImageFileName: cover.imageFileName,
                photoAspectRatio: cover.photoAspectRatio.map { CGFloat($0) },
                placeholderStyle: style
            )
        }
        return ClosetItem(
            id: category.id,
            category: category.name,
            dateAdded: category.createdAt,
            thumbnailFileName: nil,
            fullImageFileName: nil,
            placeholderStyle: style
        )
    }
}
