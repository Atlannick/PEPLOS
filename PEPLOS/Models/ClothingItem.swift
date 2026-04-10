//
//  ClothingItem.swift
//  PEPLOS
//

import Foundation

/// A persisted closet row; uploads reference on-disk files under `ClothingImageStorage` (PNG cutout + JPEG thumb, or JPEG pair).
struct ClothingItem: Identifiable, Codable, Hashable {
    let id: UUID
    var categoryId: UUID
    /// Processed display image (PNG with alpha after cutout, or JPEG), max edge ~1500px.
    var imageFileName: String?
    /// Small preview for grids (PNG or JPEG, matches display format).
    var thumbnailFileName: String?
    /// When a PNG cutout was saved, optional downscaled JPEG of the same photo for debugging / fallback.
    var originalImageFileName: String?
    /// Width ÷ height of the stored display image (nil for rows saved before this metadata existed).
    var photoAspectRatio: Double?
    /// Legacy inline payload from v2 UserDefaults; cleared after migration to files.
    var imageData: Data?
    var createdAt: Date
    /// Optional styling metadata for the local fashion engine (`FashionEngine`); nil until the user or flows set it.
    var fashionMetadata: FashionItemMetadata?
    /// Import pipeline outcome (debug / tuning); nil for legacy rows or migration JPEG-only imports.
    var importProcessingPath: ClothingImportProcessingPath?

    init(
        id: UUID = UUID(),
        categoryId: UUID,
        imageFileName: String? = nil,
        thumbnailFileName: String? = nil,
        originalImageFileName: String? = nil,
        photoAspectRatio: Double? = nil,
        imageData: Data? = nil,
        createdAt: Date = Date(),
        fashionMetadata: FashionItemMetadata? = nil,
        importProcessingPath: ClothingImportProcessingPath? = nil
    ) {
        self.id = id
        self.categoryId = categoryId
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.originalImageFileName = originalImageFileName
        self.photoAspectRatio = photoAspectRatio
        self.imageData = imageData
        self.createdAt = createdAt
        self.fashionMetadata = fashionMetadata
        self.importProcessingPath = importProcessingPath
    }

    /// True when this row has a saved photo (file-based or legacy data pending migration).
    var hasUploadedPhoto: Bool {
        imageFileName != nil || imageData != nil
    }
}
