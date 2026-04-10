//
//  ImageColorAnalyzer.swift
//  PEPLOS
//
//  Lightweight dominant-color suggestion (resize + pixel sampling + palette mapping).
//

import UIKit

enum ImageColorAnalyzer {
    /// Suggested `FashionColor` for the image, or `nil` if analysis fails.
    static func suggestFashionColor(from image: UIImage) -> FashionColor? {
        guard let rgb = averageSampledRGB(from: image) else { return nil }
        return refine(rgb)
    }

    // MARK: - Sampling

    private static let analysisDimension: CGFloat = 56

    private static func averageSampledRGB(from image: UIImage) -> (Double, Double, Double)? {
        guard let resized = resize(image, maxDimension: analysisDimension),
              let cg = resized.cgImage else { return nil }
        let w = cg.width
        let h = cg.height
        guard w > 0, h > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = w * bytesPerPixel
        var data = [UInt8](repeating: 0, count: h * bytesPerRow)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        guard let ctx = CGContext(
            data: &data,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var rSum = 0.0
        var gSum = 0.0
        var bSum = 0.0
        var count = 0

        // Skip a thin border to reduce background bias.
        let margin = max(1, min(w, h) / 14)
        for y in margin..<(h - margin) {
            let row = y * bytesPerRow
            for x in margin..<(w - margin) {
                let o = row + x * bytesPerPixel
                let a = Double(data[o + 3]) / 255.0
                if a < 0.08 { continue }
                let rp = Double(data[o]) / 255.0
                let gp = Double(data[o + 1]) / 255.0
                let bp = Double(data[o + 2]) / 255.0
                // Un-premultiply
                let invA = a > 0.001 ? 1.0 / a : 1.0
                rSum += min(1, rp * invA)
                gSum += min(1, gp * invA)
                bSum += min(1, bp * invA)
                count += 1
            }
        }

        guard count > 0 else { return nil }
        return (rSum / Double(count), gSum / Double(count), bSum / Double(count))
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        guard size.width > 1, size.height > 1 else { return nil }
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        let newSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        // `draw` applies UIImage orientation so EXIF/camera metadata maps to pixels correctly.
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Map to palette

    private static func refine(_ rgb: (Double, Double, Double)) -> FashionColor {
        let (r, g, b) = rgb
        let mx = max(r, g, b)
        let mn = min(r, g, b)
        let delta = mx - mn
        let sat = mx > 0.001 ? delta / mx : 0

        // Achromatic band → neutrals from luminance and warmth.
        if sat < 0.12 {
            let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if lum < 0.14 { return .black }
            if lum > 0.92 { return .white }
            if lum > 0.78 {
                let warm = r - b
                if warm > 0.06 { return .cream }
                return .offWhite
            }
            if lum < 0.38 { return .charcoal }
            let warm = r - b
            if warm > 0.04, g > r * 0.95 { return .beige }
            return .gray
        }

        return FashionColor.nearestInAddItemPalette(to: rgb)
    }
}
