//
//  PepEmptyState.swift
//  PEPLOS
//

import SwiftUI

struct PepEmptyState: View {
    let systemImage: String
    let message: String
    var iconSize: CGFloat = 44

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(AppTheme.subtitleGray.opacity(0.9))
                .symbolRenderingMode(.hierarchical)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtitleGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PepEmptyState(systemImage: "heart", message: "No outfit created yet")
        .padding()
        .background(AppTheme.background)
}
