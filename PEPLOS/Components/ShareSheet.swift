//
//  ShareSheet.swift
//  PEPLOS
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Presents the native share sheet (`UIActivityViewController`) from SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var onComplete: ((Bool, UIActivity.ActivityType?) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items: [Any] = activityItems.map { item in
            if let fileURL = item as? URL, fileURL.isFileURL {
                return FileURLActivityItemSource(fileURL: fileURL)
            }
            return item
        }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: applicationActivities)
        vc.completionWithItemsHandler = { activityType, completed, _, _ in
            onComplete?(completed, activityType)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class FileURLActivityItemSource: NSObject, UIActivityItemSource {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.data.identifier
    }
}
