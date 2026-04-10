//
//  BackgroundRemovalService.swift
//  PEPLOS
//
//  On-device foreground extraction using Vision (`VNGenerateForegroundInstanceMaskRequest`).
//  UI stays separate; callers run work off the main thread via `ImageProcessor` / `Task.detached`.
//

import CoreGraphics
import CoreImage
import Foundation
import UIKit
import Vision

enum BackgroundRemovalError: Error {
    case invalidImage
    case visionRequestFailed
    case noMaskObservation
    case noForegroundInstances
    case maskedImageCreationFailed
}

/// Wraps Apple’s foreground instance mask API for reusable wardrobe cutouts.
enum BackgroundRemovalService {

    /// `true` when the Vision foreground mask API is present for this OS (runtime check).
    nonisolated static var isAvailable: Bool {
        if #available(iOS 17.0, *) {
            return true
        }
        return false
    }

    /// Returns a UIImage with premultiplied alpha (transparent background outside the subject).
    /// Runs synchronously on the caller’s executor; call from `Task.detached` when off the main thread.
    nonisolated static func removeBackground(from image: UIImage) async throws -> UIImage {
        try removeBackgroundSync(from: image)
    }

    /// PNG-encoded result suitable for saving to disk.
    nonisolated static func removeBackgroundPNGData(from image: UIImage) async throws -> Data {
        let ui = try await removeBackground(from: image)
        guard let data = ui.pngData() else {
            throw BackgroundRemovalError.maskedImageCreationFailed
        }
        return data
    }

    // MARK: - Private

    nonisolated private static func removeBackgroundSync(from image: UIImage) throws -> UIImage {
        guard isAvailable else {
            throw BackgroundRemovalError.visionRequestFailed
        }
        if #available(iOS 17.0, *) {
            return try performForegroundInstanceMask(on: image)
        }
        throw BackgroundRemovalError.visionRequestFailed
    }

    @available(iOS 17.0, *)
    nonisolated private static func performForegroundInstanceMask(on image: UIImage) throws -> UIImage {
        guard let cgImage = cgImageForVision(image) else {
            throw BackgroundRemovalError.invalidImage
        }
        let request = VNGenerateForegroundInstanceMaskRequest()
        // `cgImageForVision` normalizes to `.up` orientation by redrawing into a new buffer.
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw BackgroundRemovalError.visionRequestFailed
        }

        guard let observation = request.results?.first as? VNInstanceMaskObservation else {
            throw BackgroundRemovalError.noMaskObservation
        }
        guard !observation.allInstances.isEmpty else {
            throw BackgroundRemovalError.noForegroundInstances
        }

        let buffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: false
        )

        guard let out = uiImage(from: buffer, scale: image.scale) else {
            throw BackgroundRemovalError.maskedImageCreationFailed
        }
        return out
    }

    nonisolated private static func cgImageForVision(_ image: UIImage) -> CGImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }

    nonisolated private static func uiImage(from pixelBuffer: CVPixelBuffer, scale: CGFloat) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgOut = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgOut, scale: scale, orientation: .up)
    }
}

