//
//  FavoriteColorPickerView.swift
//  PEPLOS
//

import SwiftUI

struct FavoriteColorPickerView: View {
    @ObservedObject var appSettings: AppSettingsStore

    private let columns = [
        GridItem(.adaptive(minimum: 88), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
            ForEach(FashionColor.settingsFavoritePalette, id: \.self) { color in
                let selected = appSettings.favoriteFashionColors.contains(color)
                Button {
                    appSettings.toggleFavoriteColor(color)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color.addItemSwatchColor)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                            }
                        Text(color.addItemDisplayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(selected ? AppTheme.accent : AppTheme.chipInactive)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
