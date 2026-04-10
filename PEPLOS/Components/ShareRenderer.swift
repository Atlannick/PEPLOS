//
//  ShareRenderer.swift
//  PEPLOS
//

import SwiftUI
import UIKit

/// Renders a SwiftUI view tree to a bitmap for the system share sheet.
@MainActor
enum ShareRenderer {
    /// Renders `content` at the given size. Returns `nil` if rendering fails (never force-unwraps).
    static func renderToImage<V: View>(_ content: V, size: CGSize, scale: CGFloat? = nil) -> UIImage? {
        let s = scale ?? max(1, UITraitCollection.current.displayScale)
        let framed = content.frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = s
        if let img = renderer.uiImage {
            return img
        }

        // Fallback for cases where ImageRenderer returns nil on device/runtime combos.
        let host = UIHostingController(rootView: framed)
        host.view.bounds = CGRect(origin: .zero, size: size)
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = s
        let fallback = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        return fallback
    }
}
