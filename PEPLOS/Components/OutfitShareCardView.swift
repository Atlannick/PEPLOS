//
//  OutfitShareCardView.swift
//  PEPLOS
//

import SwiftUI

/// Inputs for generating a share image card.
struct OutfitSharePayload: Equatable {
    var displayTitle: String
    var previewItems: [OutfitPreviewItem]
    var outfitItemOrder: [UUID]

    static let defaultTitle = "My Peplos Outfit"

    static func displayTitle(outfitName: String?) -> String {
        let t = outfitName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? defaultTitle : t
    }
}

/// Dedicated share-only export card (separate from in-app outfit cards).
struct OutfitShareCardView: View {
    var payload: OutfitSharePayload

    // 9:16 social-friendly output.
    private static let exportCanvas = CGSize(width: 1080, height: 1920)

    static var exportSize: CGSize { exportCanvas }

    private var orderedItems: [OutfitPreviewItem] {
        OutfitPreviewComposition.sorted(payload.previewItems, outfitOrder: payload.outfitItemOrder)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.93, blue: 0.94),
                    Color(red: 0.90, green: 0.90, blue: 0.91),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            cardShell
        }
        .frame(width: Self.exportCanvas.width, height: Self.exportCanvas.height)
    }

    private var cardShell: some View {
        VStack(spacing: 0) {
            topSection
                .padding(.top, 64)

            GeometryReader { geo in
                itemGridSection(
                    in: CGSize(
                        width: geo.size.width,
                        height: max(0, geo.size.height - 150)
                    )
                )
                    .padding(.top, 22)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 128)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            brandSection
                .padding(.bottom, 56)
        }
        .frame(width: 920, height: 1780)
        .background(
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.98, blue: 0.985),
                            Color(red: 0.95, green: 0.96, blue: 0.98),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .strokeBorder(Color.white.opacity(0.75), lineWidth: 1.5)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 28, x: 0, y: 16)
    }

    private var topSection: some View {
        VStack(spacing: 0) {
            Text("My Peplos Outfit")
                .font(.custom("SnellRoundhand-Bold", size: 86))
                .foregroundStyle(Color(red: 0.14, green: 0.14, blue: 0.18))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func itemGridSection(in size: CGSize) -> some View {
        let count = max(orderedItems.count, 1)
        let columnsCount = count <= 4 ? 2 : 3
        let rowsCount = Int(ceil(Double(count) / Double(columnsCount)))
        let spacing: CGFloat = 18
        let totalSpacing = CGFloat(max(rowsCount - 1, 0)) * spacing
        let fitted = (size.height - totalSpacing) / CGFloat(rowsCount)
        // Expand to fill available middle area while keeping a reasonable minimum.
        let cellHeight = max(146, fitted)
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columnsCount)

        return LazyVGrid(columns: columns, alignment: .center, spacing: spacing) {
            ForEach(Array(orderedItems.enumerated()), id: \.element.id) { index, item in
                gridCell(item, cellHeight: cellHeight, index: index, columnsCount: columnsCount)
            }
        }
    }

    private func gridCell(_ item: OutfitPreviewItem, cellHeight: CGFloat, index: Int, columnsCount: Int) -> some View {
        return VStack(spacing: 10) {
            Text(canonicalCategoryLabel(item.categoryName))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.22, green: 0.23, blue: 0.27))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.93, green: 0.93, blue: 0.95))

                if let ui = ClothingImageStorage.uiImage(fileName: item.thumbnailFileName) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(6)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(AppTheme.subtitleGray.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: max(122, cellHeight - 42))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: .infinity)
        .frame(minHeight: cellHeight)
    }

    private var brandSection: some View {
        HStack(spacing: 16) {
            logoMark

            Text("PEPLOS")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 58)
    }

    private var logoMark: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.23, green: 0.43, blue: 0.99),
                        Color(red: 0.21, green: 0.27, blue: 0.92),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 58, height: 58)
            .overlay {
                Image(systemName: "tshirt.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    private func canonicalCategoryLabel(_ raw: String) -> String {
        let n = raw.lowercased()
        if n.contains("hat") || n.contains("cap") { return "HAT" }
        if n.contains("top") || n.contains("shirt") || n.contains("tee") || n.contains("blouse") || n.contains("sweater") {
            return "TOP"
        }
        if n.contains("bottom") || n.contains("pant") || n.contains("jean") || n.contains("skirt") || n.contains("short") {
            return "BOTTOM"
        }
        if n.contains("shoe") || n.contains("boot") || n.contains("sneaker") || n.contains("heel") || n.contains("loafer") || n.contains("sandal") {
            return "SHOES"
        }
        if n.contains("bag") || n.contains("purse") || n.contains("tote") {
            return "BAG"
        }
        if n.contains("access") || n.contains("jewel") || n.contains("watch") || n.contains("belt") || n.contains("scarf") {
            return "ACCESSORY"
        }
        return raw.uppercased()
    }
}

#Preview {
    OutfitShareCardView(
        payload: OutfitSharePayload(
            displayTitle: OutfitSharePayload.defaultTitle,
            previewItems: [],
            outfitItemOrder: []
        )
    )
}
