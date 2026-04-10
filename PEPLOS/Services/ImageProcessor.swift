//
//  ImageProcessor.swift
//  PEPLOS
//
//  Resizes, compresses, and stores clothing photos on disk to avoid holding
//  full-resolution library images in memory or UserDefaults.
//

import Foundation
import OSLog
import UIKit

// MARK: - Storage

/// JPEG/PNG files live under Application Support / `ClothingImages`.
enum ClothingImageStorage {
    nonisolated static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("ClothingImages", isDirectory: true)
    }

    nonisolated static func fileURL(fileName: String) -> URL {
        directoryURL.appendingPathComponent(fileName)
    }

    nonisolated static func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    nonisolated static func deleteImages(
        fullImageFileName: String?,
        thumbnailFileName: String?,
        originalImageFileName: String? = nil
    ) {
        if let fullImageFileName {
            try? FileManager.default.removeItem(at: fileURL(fileName: fullImageFileName))
        }
        if let thumbnailFileName {
            try? FileManager.default.removeItem(at: fileURL(fileName: thumbnailFileName))
        }
        if let originalImageFileName {
            try? FileManager.default.removeItem(at: fileURL(fileName: originalImageFileName))
        }
    }

    /// Removes every file in the clothing images directory (factory reset).
    nonisolated static func removeAllImageFiles() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else { return }
        for url in urls {
            try? fm.removeItem(at: url)
        }
    }

    /// Loads an image from disk (call from background when decoding many at once).
    nonisolated static func uiImage(fileName: String?) -> UIImage? {
        guard let fileName else { return nil }
        let path = fileURL(fileName: fileName).path
        return UIImage(contentsOfFile: path)
    }
}

// MARK: - Processing

enum ImageProcessingError: Error {
    case invalidImageData
    case jpegEncodeFailed
    case pngEncodeFailed
}

// MARK: - Import logging (debug)

private enum ClothingImportLog {
    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PEPLOS",
        category: "ClothingImport"
    )

    nonisolated static func cutoutSuccess(importId: String, fileType: String, path: ClothingImportProcessingPath) {
        logger.debug(
            "cutout_success import_id=\(importId, privacy: .public) file_type=\(fileType, privacy: .public) path=\(path.rawValue, privacy: .public)"
        )
    }

    nonisolated static func importFinished(importId: String, fileType: String, path: ClothingImportProcessingPath) {
        logger.debug(
            "import_finished import_id=\(importId, privacy: .public) file_type=\(fileType, privacy: .public) path=\(path.rawValue, privacy: .public)"
        )
    }
}

/// Result of importing a clothing photo: display + thumbnail on disk, optional original JPEG when cutout succeeded.
struct ProcessedClothingImport: Sendable {
    var fullImageFileName: String
    var thumbnailFileName: String
    /// Downscaled JPEG backup when a PNG cutout was saved (`*_orig.jpg`); nil when using JPEG-only import.
    var originalImageFileName: String?
    var photoAspectRatio: CGFloat
    /// Which pipeline produced the saved files; nil for legacy migration JPEG-only imports.
    var importProcessingPath: ClothingImportProcessingPath?
}

/// Resizing / JPEG settings: display max edge ~1500 px, thumbnail ~300 px, qualities ~0.82 / 0.78.
enum ImageProcessor {
    /// Downscales so the longest edge is at most `maxDimension` **pixels**.
    ///
    /// Uses `UIImage.size` × `scale` for pixel dimensions so EXIF / camera orientation matches on-screen appearance.
    /// Raw `CGImage` width/height ignore orientation and will squash or stretch portrait photos into landscape rects.
    nonisolated static func resizeForDisplay(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 1, size.height > 1 else { return image }
        let pixelWidth = size.width * image.scale
        let pixelHeight = size.height * image.scale
        let downscale = min(maxDimension / pixelWidth, maxDimension / pixelHeight, 1)
        guard downscale < 1 else { return image }
        let newW = floor(pixelWidth * downscale)
        let newH = floor(pixelHeight * downscale)
        let newSize = CGSize(width: newW, height: newH)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Smaller square-ish preview for lists (from an already display-sized image).
    nonisolated static func makeThumbnail(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        resizeForDisplay(image, maxDimension: maxDimension)
    }

    nonisolated static func saveJPEGToDisk(_ data: Data, fileName: String) throws {
        try ClothingImageStorage.ensureDirectoryExists()
        let url = ClothingImageStorage.fileURL(fileName: fileName)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    nonisolated static func savePNGToDisk(_ data: Data, fileName: String) throws {
        try ClothingImageStorage.ensureDirectoryExists()
        let url = ClothingImageStorage.fileURL(fileName: fileName)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    /// Width ÷ height as displayed (`UIImage.size` reflects orientation; do not use raw `CGImage` extents).
    nonisolated static func aspectRatio(of image: UIImage) -> CGFloat {
        let s = image.size
        guard s.height > 0 else { return 1 }
        return s.width / s.height
    }

    // MARK: - Legacy / migration (JPEG only, no Vision)

    /// Decodes `data`, downscales, writes two JPEGs — used for one-time migration from inline blobs (no Vision).
    nonisolated static func processImportDataJPEGOnly(_ data: Data) throws -> ProcessedClothingImport {
        try autoreleasepool {
            guard let image = UIImage(data: data) else { throw ImageProcessingError.invalidImageData }
            return try processImportUIImageJPEGOnly(image)
        }
    }

    nonisolated static func processImportUIImageJPEGOnly(_ image: UIImage) throws -> ProcessedClothingImport {
        let display = resizeForDisplay(image, maxDimension: 1500)
        let thumb = makeThumbnail(display, maxDimension: 300)
        let id = UUID().uuidString
        let fullName = "\(id)_d.jpg"
        let thumbName = "\(id)_t.jpg"
        guard let fullData = display.jpegData(compressionQuality: 0.82),
              let thumbData = thumb.jpegData(compressionQuality: 0.78)
        else {
            throw ImageProcessingError.jpegEncodeFailed
        }
        try saveJPEGToDisk(fullData, fileName: fullName)
        try saveJPEGToDisk(thumbData, fileName: thumbName)
        return ProcessedClothingImport(
            fullImageFileName: fullName,
            thumbnailFileName: thumbName,
            originalImageFileName: nil,
            photoAspectRatio: aspectRatio(of: display),
            importProcessingPath: nil
        )
    }

    // MARK: - User import (foreground cutout when supported)

    /// Full import pipeline: optional on-device background removal, PNG display + optional original JPEG backup, or JPEG fallback.
    /// Call from `Task.detached` for heavy library imports so the main thread stays responsive.
    nonisolated static func processImportData(_ data: Data) async throws -> ProcessedClothingImport {
        // Memory: decode + downscale inside a pool so the full-resolution `UIImage` from `UIImage(data:)` is released before Vision runs.
        let display: UIImage = try autoreleasepool {
            guard let image = UIImage(data: data) else { throw ImageProcessingError.invalidImageData }
            return resizeForDisplay(image, maxDimension: 1500)
        }
        return try await processImportFromDisplayImage(display)
    }

    nonisolated static func processImportUIImage(_ image: UIImage) async throws -> ProcessedClothingImport {
        // Memory: the camera `UIImage` remains referenced until this async function returns; downsample immediately so Vision only sees the display-sized buffer.
        let display = autoreleasepool {
            resizeForDisplay(image, maxDimension: 1500)
        }
        return try await processImportFromDisplayImage(display)
    }

    nonisolated private static func processImportFromDisplayImage(_ display: UIImage) async throws -> ProcessedClothingImport {
        let id = UUID().uuidString

        guard BackgroundRemovalService.isAvailable else {
            ClothingImportLog.importFinished(importId: id, fileType: "jpeg", path: .jpegFallbackUnsupportedIOS)
            return try saveJPEGPairFromDisplayImage(display, id: id, path: .jpegFallbackUnsupportedIOS)
        }

        do {
            let cutout = try await BackgroundRemovalService.removeBackground(from: display)

            guard CutoutPostProcessing.isQualityAcceptable(cutout) else {
                ClothingImportLog.importFinished(importId: id, fileType: "jpeg", path: .jpegFallbackQualityFailed)
                return try saveJPEGPairFromDisplayImage(display, id: id, path: .jpegFallbackQualityFailed)
            }

            guard let finalDisplay = CutoutPostProcessing.addingTransparentMarginAroundSubject(cutout) else {
                ClothingImportLog.importFinished(importId: id, fileType: "jpeg", path: .jpegFallbackQualityFailed)
                return try saveJPEGPairFromDisplayImage(display, id: id, path: .jpegFallbackQualityFailed)
            }

            guard let origJPEG = display.jpegData(compressionQuality: 0.92) else {
                ClothingImportLog.importFinished(importId: id, fileType: "jpeg", path: .jpegFallbackQualityFailed)
                return try saveJPEGPairFromDisplayImage(display, id: id, path: .jpegFallbackQualityFailed)
            }
            let origName = "\(id)_orig.jpg"
            try saveJPEGToDisk(origJPEG, fileName: origName)

            guard let pngData = finalDisplay.pngData() else {
                ClothingImportLog.importFinished(importId: id, fileType: "jpeg", path: .jpegFallbackQualityFailed)
                try? FileManager.default.removeItem(at: ClothingImageStorage.fileURL(fileName: origName))
                return try saveJPEGPairFromDisplayImage(display, id: id, path: .jpegFallbackQualityFailed)
            }
            let fullName = "\(id)_d.png"
            try savePNGToDisk(pngData, fileName: fullName)

            // Thumbnails always come from the same final display asset written above (padded cutout), not the pre-cutout source.
            let thumb = makeThumbnail(finalDisplay, maxDimension: 300)
            guard let thumbPNG = thumb.pngData() else {
                ClothingImportLog.importFinished(importId: id, fileType: "jpeg", path: .jpegFallbackQualityFailed)
                try? FileManager.default.removeItem(at: ClothingImageStorage.fileURL(fileName: fullName))
                try? FileManager.default.removeItem(at: ClothingImageStorage.fileURL(fileName: origName))
                return try saveJPEGPairFromDisplayImage(display, id: id, path: .jpegFallbackQualityFailed)
            }
            let thumbName = "\(id)_t.png"
            try savePNGToDisk(thumbPNG, fileName: thumbName)

            ClothingImportLog.cutoutSuccess(importId: id, fileType: "png", path: .pngCutout)
            return ProcessedClothingImport(
                fullImageFileName: fullName,
                thumbnailFileName: thumbName,
                originalImageFileName: origName,
                photoAspectRatio: aspectRatio(of: finalDisplay),
                importProcessingPath: .pngCutout
            )
        } catch {
            ClothingImportLog.importFinished(importId: id, fileType: "jpeg", path: .jpegFallbackVisionFailed)
            return try saveJPEGPairFromDisplayImage(display, id: id, path: .jpegFallbackVisionFailed)
        }
    }

    /// Writes JPEG pair using a fixed id prefix (after failed cutout we still want matching `_d` / `_t` names).
    nonisolated private static func saveJPEGPairFromDisplayImage(
        _ display: UIImage,
        id: String,
        path: ClothingImportProcessingPath
    ) throws -> ProcessedClothingImport {
        let thumb = makeThumbnail(display, maxDimension: 300)
        let fullName = "\(id)_d.jpg"
        let thumbName = "\(id)_t.jpg"
        guard let fullData = display.jpegData(compressionQuality: 0.82),
              let thumbData = thumb.jpegData(compressionQuality: 0.78)
        else {
            throw ImageProcessingError.jpegEncodeFailed
        }
        try saveJPEGToDisk(fullData, fileName: fullName)
        try saveJPEGToDisk(thumbData, fileName: thumbName)
        return ProcessedClothingImport(
            fullImageFileName: fullName,
            thumbnailFileName: thumbName,
            originalImageFileName: nil,
            photoAspectRatio: aspectRatio(of: display),
            importProcessingPath: path
        )
    }
}
