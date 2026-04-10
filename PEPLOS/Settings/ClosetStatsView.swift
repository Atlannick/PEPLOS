//
//  ClosetStatsView.swift
//  PEPLOS
//

import SwiftUI

struct ClosetStatsView: View {
    var totalItems: Int
    var totalSavedOutfits: Int
    var totalCategories: Int

    var body: some View {
        VStack(spacing: 0) {
            statRow(title: "Total Items", value: "\(totalItems)")
            Divider().opacity(0.35).padding(.vertical, 12)
            statRow(title: "Total Saved Outfits", value: "\(totalSavedOutfits)")
            Divider().opacity(0.35).padding(.vertical, 12)
            statRow(title: "Total Categories", value: "\(totalCategories)")
        }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary.opacity(0.72))
            Spacer(minLength: 12)
            Text(value)
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.primary)
        }
    }
}
