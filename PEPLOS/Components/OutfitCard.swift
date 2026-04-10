//
//  OutfitCard.swift
//  PEPLOS
//

import SwiftUI

struct OutfitCard: View {
    @EnvironmentObject private var closet: ClosetStore

    let outfit: SavedOutfit
    var showThumbnails: Bool = true
    var showDetails: Bool = true
    /// When set, the whole card opens the expanded outfit view (parent presents sheet).
    var onTap: (() -> Void)? = nil

    private var previewItems: [OutfitPreviewItem] {
        closet.outfitPreviewItems(forItemIds: outfit.itemIds)
    }

    private var cardColors: OutfitCardPalette.Colors {
        OutfitCardPalette.colors(for: outfit.id)
    }

    private var previewGradient: LinearGradient {
        LinearGradient(
            colors: [cardColors.previewTop, cardColors.previewBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        let chrome = cardChrome
        Group {
            if let onTap {
                Button(action: onTap) {
                    chrome
                }
                .buttonStyle(.plain)
            } else {
                chrome
            }
        }
    }

    private var cardChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(previewGradient)

                OutfitPreviewView(items: previewItems, outfitItemOrder: outfit.itemIds)
                    .padding(14)
            }
            .aspectRatio(0.78, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.38), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 0) {
                if showDetails {
                    HStack(alignment: .center, spacing: 10) {
                        Text(outfit.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 0)
                    }

                    Text("\(outfit.itemCount) items")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtitleGray)
                        .padding(.top, 6)
                }

                if showThumbnails {
                    thumbnailStrip
                        .padding(.top, showDetails ? 12 : 0)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardColors.shell)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .pepCardShadow()
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var thumbnailStrip: some View {
        Group {
            if outfit.itemIds.isEmpty {
                HStack(spacing: Self.thumbSpacing) {
                    ClothingPlaceholderImage(style: .blue, cornerRadius: 10)
                        .frame(width: Self.thumbSize, height: Self.thumbSize)
                    ClothingPlaceholderImage(style: .mint, cornerRadius: 10)
                        .frame(width: Self.thumbSize, height: Self.thumbSize)
                }
            } else {
                OutfitThumbnailFlowLayout(spacing: Self.thumbSpacing, itemSize: Self.thumbSize) {
                    ForEach(outfit.itemIds, id: \.self) { id in
                        thumbnailCell(for: id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private static let thumbSize: CGFloat = 44
    private static let thumbSpacing: CGFloat = 8

    @ViewBuilder
    private func thumbnailCell(for id: UUID) -> some View {
        let index = outfit.itemIds.firstIndex(of: id) ?? 0
        if let name = closet.items.first(where: { $0.id == id })?.thumbnailFileName {
            let url = ClothingImageStorage.fileURL(fileName: name)
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.chipInactive)
                        image
                            .resizable()
                            .scaledToFit()
                    }
                    .frame(width: Self.thumbSize, height: Self.thumbSize)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                case .empty:
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.chipInactive)
                        .frame(width: Self.thumbSize, height: Self.thumbSize)
                        .overlay { ProgressView().controlSize(.small) }
                case .failure:
                    let style: ClothingPlaceholderStyle = index % 2 == 0 ? .blue : .mint
                    ClothingPlaceholderImage(style: style, cornerRadius: 10)
                        .frame(width: Self.thumbSize, height: Self.thumbSize)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            let style: ClothingPlaceholderStyle = index % 2 == 0 ? .blue : .mint
            ClothingPlaceholderImage(style: style, cornerRadius: 10)
                .frame(width: Self.thumbSize, height: Self.thumbSize)
        }
    }
}

// MARK: - Per-outfit accent (stable from UUID, looks random across outfits)

private enum OutfitCardPalette {
    struct Colors {
        let previewTop: Color
        let previewBottom: Color
        let shell: Color
    }

    /// Hues spread around the wheel so adjacent picks look different; includes several warm gradients.
    private static let options: [Colors] = [
        // Warm — honey & butter
        Colors(
            previewTop: Color(red: 1.0, green: 0.93, blue: 0.70),
            previewBottom: Color(red: 0.96, green: 0.76, blue: 0.38),
            shell: Color(red: 1.0, green: 0.99, blue: 0.96)
        ),
        // Warm — terracotta
        Colors(
            previewTop: Color(red: 0.97, green: 0.79, blue: 0.66),
            previewBottom: Color(red: 0.86, green: 0.50, blue: 0.40),
            shell: Color(red: 1.0, green: 0.98, blue: 0.96)
        ),
        // Warm — coral sunset
        Colors(
            previewTop: Color(red: 1.0, green: 0.76, blue: 0.66),
            previewBottom: Color(red: 0.94, green: 0.46, blue: 0.50),
            shell: Color(red: 1.0, green: 0.98, blue: 0.98)
        ),
        // Warm — amber gold
        Colors(
            previewTop: Color(red: 1.0, green: 0.87, blue: 0.55),
            previewBottom: Color(red: 0.90, green: 0.62, blue: 0.28),
            shell: Color(red: 1.0, green: 0.99, blue: 0.95)
        ),
        // Warm — dusty rose
        Colors(
            previewTop: Color(red: 0.98, green: 0.78, blue: 0.82),
            previewBottom: Color(red: 0.86, green: 0.48, blue: 0.58),
            shell: Color(red: 1.0, green: 0.98, blue: 0.99)
        ),
        // Warm — peach cream
        Colors(
            previewTop: Color(red: 1.0, green: 0.85, blue: 0.74),
            previewBottom: Color(red: 0.96, green: 0.62, blue: 0.48),
            shell: Color(red: 1.0, green: 0.99, blue: 0.98)
        ),
        // Cool — ocean teal
        Colors(
            previewTop: Color(red: 0.62, green: 0.88, blue: 0.90),
            previewBottom: Color(red: 0.32, green: 0.64, blue: 0.68),
            shell: Color(red: 0.96, green: 0.99, blue: 0.99)
        ),
        // Cool — sage & moss
        Colors(
            previewTop: Color(red: 0.74, green: 0.88, blue: 0.72),
            previewBottom: Color(red: 0.42, green: 0.62, blue: 0.46),
            shell: Color(red: 0.98, green: 1.0, blue: 0.98)
        ),
        // Cool — clear sky
        Colors(
            previewTop: Color(red: 0.64, green: 0.80, blue: 0.99),
            previewBottom: Color(red: 0.38, green: 0.58, blue: 0.94),
            shell: Color(red: 0.97, green: 0.98, blue: 1.0)
        ),
        // Cool — icy cyan
        Colors(
            previewTop: Color(red: 0.70, green: 0.93, blue: 0.98),
            previewBottom: Color(red: 0.42, green: 0.78, blue: 0.88),
            shell: Color(red: 0.97, green: 0.995, blue: 1.0)
        ),
        // Purple — orchid
        Colors(
            previewTop: Color(red: 0.88, green: 0.70, blue: 0.96),
            previewBottom: Color(red: 0.66, green: 0.42, blue: 0.82),
            shell: Color(red: 0.99, green: 0.97, blue: 1.0)
        ),
        // Purple — dusk indigo
        Colors(
            previewTop: Color(red: 0.76, green: 0.74, blue: 0.98),
            previewBottom: Color(red: 0.48, green: 0.46, blue: 0.82),
            shell: Color(red: 0.98, green: 0.98, blue: 1.0)
        ),
        // Berry — plum wine
        Colors(
            previewTop: Color(red: 0.90, green: 0.66, blue: 0.80),
            previewBottom: Color(red: 0.62, green: 0.36, blue: 0.52),
            shell: Color(red: 0.99, green: 0.97, blue: 0.99)
        ),
        // Neutral-warm — sand & oat
        Colors(
            previewTop: Color(red: 0.94, green: 0.88, blue: 0.78),
            previewBottom: Color(red: 0.78, green: 0.66, blue: 0.52),
            shell: Color(red: 0.99, green: 0.99, blue: 0.97)
        ),
        // Contrast — soft charcoal mist (still light for cards)
        Colors(
            previewTop: Color(red: 0.82, green: 0.84, blue: 0.88),
            previewBottom: Color(red: 0.58, green: 0.62, blue: 0.70),
            shell: Color(red: 0.98, green: 0.98, blue: 0.99)
        ),
    ]

    static func colors(for outfitId: UUID) -> Colors {
        let idx = stablePaletteIndex(for: outfitId)
        return options[idx % options.count]
    }

    /// Deterministic from UUID bytes (same outfit always same colors; different outfits spread across palette).
    private static func stablePaletteIndex(for id: UUID) -> Int {
        let u = id.uuid
        let bytes: [UInt8] = [
            u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7,
            u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15,
        ]
        var mix: UInt64 = 0
        for (i, b) in bytes.enumerated() {
            mix &+= UInt64(b) &* UInt64(i &* 31 &+ 1)
        }
        return Int(mix % UInt64(max(options.count, 1)))
    }
}

// MARK: - Wrapping thumbnail rows (card grows vertically as needed)

private struct OutfitThumbnailFlowLayout: Layout {
    var spacing: CGFloat
    var itemSize: CGFloat
    var minimumItemsPerRow: Int = 3

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let dims = proposal.replacingUnspecifiedDimensions(by: CGSize(width: 280, height: itemSize))
        let w = dims.width.isFinite && dims.width > 0 ? dims.width : 280
        let count = subviews.count
        guard count > 0 else {
            return CGSize(width: w, height: itemSize)
        }
        let fittedItemSize = Self.fittedItemSize(
            forWidth: w,
            preferredItemSize: itemSize,
            spacing: spacing,
            minimumItemsPerRow: minimumItemsPerRow,
            itemCount: count
        )
        let perRow = Self.itemsPerRow(forWidth: w, itemSize: fittedItemSize, spacing: spacing, maxItems: count)
        let rows = (count + perRow - 1) / perRow
        let h = CGFloat(rows) * fittedItemSize + CGFloat(max(0, rows - 1)) * spacing
        return CGSize(width: w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let w = bounds.width
        guard w > 0 else { return }
        let count = subviews.count
        let fittedItemSize = Self.fittedItemSize(
            forWidth: w,
            preferredItemSize: itemSize,
            spacing: spacing,
            minimumItemsPerRow: minimumItemsPerRow,
            itemCount: count
        )
        let perRow = Self.itemsPerRow(forWidth: w, itemSize: fittedItemSize, spacing: spacing, maxItems: count)
        var x = bounds.minX
        var y = bounds.minY
        var col = 0
        for subview in subviews {
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: fittedItemSize, height: fittedItemSize)
            )
            col += 1
            if col >= perRow {
                col = 0
                x = bounds.minX
                y += fittedItemSize + spacing
            } else {
                x += fittedItemSize + spacing
            }
        }
    }

    private static func fittedItemSize(
        forWidth width: CGFloat,
        preferredItemSize: CGFloat,
        spacing: CGFloat,
        minimumItemsPerRow: Int,
        itemCount: Int
    ) -> CGFloat {
        let requiredItems = min(max(1, minimumItemsPerRow), max(1, itemCount))
        guard requiredItems > 1 else { return preferredItemSize }

        let availableWidth = width - CGFloat(requiredItems - 1) * spacing
        guard availableWidth > 0 else { return preferredItemSize }

        return min(preferredItemSize, floor(availableWidth / CGFloat(requiredItems)))
    }

    private static func itemsPerRow(forWidth w: CGFloat, itemSize: CGFloat, spacing: CGFloat, maxItems: Int) -> Int {
        let cell = itemSize + spacing
        let ratio = (w + spacing) / cell
        guard ratio.isFinite, ratio > 0 else { return max(1, maxItems) }
        return max(1, min(maxItems, Int(floor(ratio))))
    }
}

#Preview {
    ScrollView {
        OutfitCard(outfit: .previewHadi, onTap: {})
            .padding()
    }
    .background(AppTheme.background)
    .environmentObject(ClosetStore())
}
