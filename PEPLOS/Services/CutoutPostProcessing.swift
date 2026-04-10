//
//  CutoutPostProcessing.swift
//  PEPLOS
//
//  Lightweight validation and padding for Vision foreground cutouts before saving.
//

import CoreGraphics
import UIKit

// MARK: - Tunable quality thresholds (conservative defaults; tune after on-device testing)

/// Central place to adjust cutout acceptance — all quality checks read from here.
enum CutoutQualityConfiguration {
    /// Analysis runs on a downscaled copy (max long edge in points/pixels at scale 1).
    nonisolated static let analysisMaxDimension: CGFloat = 256

    /// Minimum fraction of pixels with meaningful alpha (foreground vs empty frame).
    nonisolated static let minForegroundFraction: CGFloat = 0.028
    /// Too many fully opaque pixels → likely no real matting.
    nonisolated static let maxOpaqueFraction: CGFloat = 0.90
    /// Mean alpha near 1.0 → flat opaque plate.
    nonisolated static let maxMeanAlpha: CGFloat = 0.92
    /// Tight bbox of foreground vs frame — reject tiny subjects.
    nonisolated static let minSubjectBBoxAreaFraction: CGFloat = 0.038

    /// Alpha thresholds on 0…255 scale (premultiplied RGBA samples).
    nonisolated static let foregroundAlphaThreshold: Int = 26
    nonisolated static let opaqueAlphaThreshold: Int = 242
    /// Slightly looser threshold for full-res bbox scan.
    nonisolated static let bboxForegroundAlphaThreshold: Int = 8

    /// Safety expansion (pixels) applied to the detected bbox before cropping.
    nonisolated static let bboxHorizontalExpansionPixels: Int = 6
    nonisolated static let bboxTopExpansionPixels: Int = 6
    /// Extra protection for hems/soles that often have faint alpha near the bottom edge.
    nonisolated static let bboxBottomExpansionPixels: Int = 16

    /// Transparent margin around the tight subject bounds (bitmap pixel units of the given image).
    nonisolated static let paddingMarginPixels: CGFloat = 22
}

// MARK: - Quality

enum CutoutPostProcessing {

    /// Returns false when the cutout is clearly unusable (flat opaque, empty, or tiny subject).
    nonisolated static func isQualityAcceptable(_ image: UIImage) -> Bool {
        guard let stats = analyzeForQuality(image) else { return false }
        let c = CutoutQualityConfiguration.self
        if stats.meanAlpha >= c.maxMeanAlpha { return false }
        if stats.foregroundFraction < c.minForegroundFraction { return false }
        if stats.opaqueFraction >= c.maxOpaqueFraction { return false }
        if stats.bboxAreaFraction < c.minSubjectBBoxAreaFraction { return false }
        return true
    }

    /// Expands the canvas with clear pixels around the subject; keeps the subject centered in the new image.
    nonisolated static func addingTransparentMarginAroundSubject(_ image: UIImage) -> UIImage? {
        guard let bboxPixels = alphaBoundingBoxPixels(for: image) else { return nil }
        guard bboxPixels.width >= 1, bboxPixels.height >= 1 else { return nil }

        let scale = image.scale
        let marginPx = CutoutQualityConfiguration.paddingMarginPixels * max(1, scale)
        let marginPt = marginPx / scale
        let bboxMinXpt = bboxPixels.minX / scale
        let bboxMinYpt = bboxPixels.minY / scale

        let outWpt = bboxPixels.width / scale + 2 * marginPt
        let outHpt = bboxPixels.height / scale + 2 * marginPt

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outWpt, height: outHpt), format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(
                x: marginPt - bboxMinXpt,
                y: marginPt - bboxMinYpt,
                width: image.size.width,
                height: image.size.height
            ))
        }
    }

    // MARK: - Analysis (downscaled)

    private struct AlphaStats {
        var meanAlpha: CGFloat
        var foregroundFraction: CGFloat
        var opaqueFraction: CGFloat
        var bboxAreaFraction: CGFloat
    }

    private nonisolated static func analyzeForQuality(_ image: UIImage) -> AlphaStats? {
        autoreleasepool {
            let sample = ImageProcessor.resizeForDisplay(image, maxDimension: CutoutQualityConfiguration.analysisMaxDimension)
            guard let cg = sample.cgImage,
                  let rgba = rgba8PremultipliedData(from: cg) else { return nil }
            let w = rgba.width
            let h = rgba.height
            let count = w * h
            guard count > 0 else { return nil }

            let c = CutoutQualityConfiguration.self
            var sumAlpha: UInt64 = 0
            var foregroundCount = 0
            var opaqueCount = 0
            var minX = w
            var maxX = -1
            var minY = h
            var maxY = -1
            let fgThreshold = c.foregroundAlphaThreshold
            let opaqueThreshold = c.opaqueAlphaThreshold

            for y in 0..<h {
                let row = y * w * 4
                for x in 0..<w {
                    let a = Int(rgba.bytes[row + x * 4 + 3])
                    sumAlpha += UInt64(a)
                    if a > fgThreshold {
                        foregroundCount += 1
                        if x < minX { minX = x }
                        if x > maxX { maxX = x }
                        if y < minY { minY = y }
                        if y > maxY { maxY = y }
                    }
                    if a >= opaqueThreshold {
                        opaqueCount += 1
                    }
                }
            }

            let n = CGFloat(count)
            let meanAlpha = CGFloat(sumAlpha) / (n * 255)
            let foregroundFraction = CGFloat(foregroundCount) / n
            let opaqueFraction = CGFloat(opaqueCount) / n

            let bboxAreaFraction: CGFloat
            if foregroundCount > 0, minX <= maxX, minY <= maxY {
                let bw = maxX - minX + 1
                let bh = maxY - minY + 1
                bboxAreaFraction = CGFloat(bw * bh) / n
            } else {
                bboxAreaFraction = 0
            }

            return AlphaStats(
                meanAlpha: meanAlpha,
                foregroundFraction: foregroundFraction,
                opaqueFraction: opaqueFraction,
                bboxAreaFraction: bboxAreaFraction
            )
        }
    }

    // MARK: - Bounding box (full resolution, pixel space)

    private struct PixelRect {
        var minX: CGFloat
        var minY: CGFloat
        var width: CGFloat
        var height: CGFloat
    }

    /// Axis-aligned bounds of pixels with meaningful alpha, in **pixels** (top-left origin).
    private nonisolated static func alphaBoundingBoxPixels(for image: UIImage) -> PixelRect? {
        autoreleasepool {
            guard let cg = image.cgImage,
                  let rgba = rgba8PremultipliedData(from: cg) else { return nil }
            let w = rgba.width
            let h = rgba.height
            let fgThreshold = CutoutQualityConfiguration.bboxForegroundAlphaThreshold
            var minX = w
            var maxX = -1
            var minY = h
            var maxY = -1

            for y in 0..<h {
                let row = y * w * 4
                for x in 0..<w {
                    let a = Int(rgba.bytes[row + x * 4 + 3])
                    if a > fgThreshold {
                        if x < minX { minX = x }
                        if x > maxX { maxX = x }
                        if y < minY { minY = y }
                        if y > maxY { maxY = y }
                    }
                }
            }

            guard maxX >= minX, maxY >= minY else { return nil }
            let c = CutoutQualityConfiguration.self
            let expandedMinX = max(0, minX - c.bboxHorizontalExpansionPixels)
            let expandedMaxX = min(w - 1, maxX + c.bboxHorizontalExpansionPixels)
            let expandedMinY = max(0, minY - c.bboxTopExpansionPixels)
            let expandedMaxY = min(h - 1, maxY + c.bboxBottomExpansionPixels)
            return PixelRect(
                minX: CGFloat(expandedMinX),
                minY: CGFloat(expandedMinY),
                width: CGFloat(expandedMaxX - expandedMinX + 1),
                height: CGFloat(expandedMaxY - expandedMinY + 1)
            )
        }
    }

    private struct RGBA8Data {
        var width: Int
        var height: Int
        var bytes: [UInt8]
    }

    /// Memory: allocates a full-frame RGBA buffer; keep scoped to `autoreleasepool` in callers.
    private nonisolated static func rgba8PremultipliedData(from cgImage: CGImage) -> RGBA8Data? {
        let w = cgImage.width
        let h = cgImage.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &bytes,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: space,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        return RGBA8Data(width: w, height: h, bytes: bytes)
    }
}
