//
//  SettingsSections.swift
//  PEPLOS
//
//  Shared layout primitives for the Settings screen (premium cards, spacing).
//

import SwiftUI

struct SettingsSectionCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .pepCardShadow()
    }
}

enum PeplosAppVersion {
    static var marketingAndBuild: String {
        let version = normalizedInfoValue(forKey: "CFBundleShortVersionString")
        let build = normalizedInfoValue(forKey: "CFBundleVersion")

        if let version, let build, build != version {
            return "\(version) (\(build))"
        }
        if let version {
            return version
        }
        if let build {
            return build
        }
        return "Unavailable"
    }

    private static func normalizedInfoValue(forKey key: String) -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) else {
            return nil
        }
        let text = String(describing: rawValue).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
