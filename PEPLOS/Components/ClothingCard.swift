//
//  ClothingCard.swift
//  PEPLOS
//

import SwiftUI

struct ClothingCard: View {
    let item: ClosetItem
    var showDate: Bool = false
    /// When `nil`, the image expands to fill a grid column.
    var fixedWidth: CGFloat? = 132

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            photoArea
                .frame(maxWidth: .infinity, alignment: .leading)
                .pepSubtleShadow()

            Text(item.category)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)

            if showDate {
                Text(Self.dateFormatter.string(from: item.dateAdded))
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtitleGray)
            }
        }
    }

    /// Matches empty-category tiles; also used when aspect ratio is unknown so loading/error placeholders keep full card size (not a tiny dot).
    private static let defaultTileAspectRatio: CGFloat = 0.85

    @ViewBuilder
    private var photoArea: some View {
        if item.hasPhoto {
            if let w = fixedWidth {
                if let ar = item.photoAspectRatio {
                    itemImage
                        .aspectRatio(ar, contentMode: .fit)
                        .frame(width: w)
                } else {
                    itemImage
                        .aspectRatio(Self.defaultTileAspectRatio, contentMode: .fit)
                        .frame(width: w)
                }
            } else {
                if let ar = item.photoAspectRatio {
                    itemImage
                        .aspectRatio(ar, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                } else {
                    itemImage
                        .aspectRatio(Self.defaultTileAspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
            }
        } else {
            ClothingPlaceholderImage(style: item.placeholderStyle, cornerRadius: 20)
                .aspectRatio(Self.defaultTileAspectRatio, contentMode: .fit)
                .frame(maxWidth: fixedWidth ?? .infinity)
        }
    }

    @ViewBuilder
    private var itemImage: some View {
        if let name = item.thumbnailFileName {
            let url = ClothingImageStorage.fileURL(fileName: name)
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                case .empty:
                    ZStack {
                        ClothingPlaceholderImage(style: item.placeholderStyle, cornerRadius: 20)
                        ProgressView()
                            .tint(.white.opacity(0.95))
                    }
                case .failure:
                    ClothingPlaceholderImage(style: item.placeholderStyle, cornerRadius: 20)
                @unknown default:
                    ClothingPlaceholderImage(style: item.placeholderStyle, cornerRadius: 20)
                }
            }
        } else {
            ClothingPlaceholderImage(style: item.placeholderStyle, cornerRadius: 20)
        }
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 14) {
            ClothingCard(item: ClosetItem(category: "Tops", placeholderStyle: .blue))
            ClothingCard(
                item: ClosetItem(category: "Bottoms", placeholderStyle: .mint),
                showDate: true,
                fixedWidth: 160
            )
        }
    }
    .padding()
    .background(AppTheme.background)
}
