//
//  SectionHeader.swift
//  PEPLOS
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var showSeeAll: Bool = true
    var seeAllAction: () -> Void = {}

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Spacer()

            if showSeeAll {
                Button("See All", action: seeAllAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SectionHeader(title: "Recently Added")
        SectionHeader(title: "Your Outfits", showSeeAll: false)
    }
    .padding()
    .background(AppTheme.background)
}
