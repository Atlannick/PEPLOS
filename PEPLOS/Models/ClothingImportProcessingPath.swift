//
//  ClothingImportProcessingPath.swift
//  PEPLOS
//
//  Persisted outcome of the clothing photo import pipeline (for debugging / tuning).
//

import Foundation

/// How the on-disk display asset was produced. Stored on `ClothingItem`; production UI ignores this.
enum ClothingImportProcessingPath: String, Codable, Hashable, Sendable {
    case pngCutout = "png_cutout"
    case jpegFallbackVisionFailed = "jpeg_fallback_vision_failed"
    case jpegFallbackQualityFailed = "jpeg_fallback_quality_failed"
    case jpegFallbackUnsupportedIOS = "jpeg_fallback_unsupported_ios"
}
