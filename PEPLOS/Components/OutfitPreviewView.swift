//
//  OutfitPreviewView.swift
//  PEPLOS
//

import SwiftUI

/// One closet photo eligible for the outfit composition (has image files and a category).
struct OutfitPreviewItem: Identifiable, Equatable {
    let id: UUID
    let categoryName: String
    let thumbnailFileName: String
}

extension ClosetStore {
    /// Resolves outfit item IDs in list order, skipping missing rows or items without photos.
    func outfitPreviewItems(forItemIds ids: [UUID]) -> [OutfitPreviewItem] {
        ids.compactMap { id in
            guard let item = items.first(where: { $0.id == id }),
                  let thumb = item.thumbnailFileName,
                  let cat = categories.first(where: { $0.id == item.categoryId })
            else { return nil }
            return OutfitPreviewItem(id: id, categoryName: cat.name, thumbnailFileName: thumb)
        }
    }
}

// MARK: - Category-aware ordering (v1)

enum OutfitPreviewComposition {
    /// Lower = higher in the stack (top garment first, then bottom, then accents).
    static func layerRank(for categoryName: String) -> Int {
        let n = categoryName.lowercased()
        if n.contains("top") || n.contains("shirt") || n.contains("sweater") || n.contains("blouse") || n.contains("tee") {
            return 0
        }
        if n.contains("outerwear") || n.contains("jacket") || n.contains("coat") || n.contains("blazer") {
            return 1
        }
        if n.contains("bottom") || n.contains("pant") || n.contains("skirt") || n.contains("short") || n.contains("jean") {
            return 2
        }
        if n.contains("shoe") || n.contains("boot") || n.contains("sneaker") || n.contains("loafer") || n.contains("heel") {
            return 3
        }
        if n.contains("access") || n.contains("bag") || n.contains("hat") || n.contains("belt")
            || n.contains("scarf") || n.contains("jewel") || n.contains("watch") || n.contains("sock") {
            return 4
        }
        return 5
    }

    static func sorted(_ items: [OutfitPreviewItem], outfitOrder: [UUID]) -> [OutfitPreviewItem] {
        let orderIndex = Dictionary(uniqueKeysWithValues: outfitOrder.enumerated().map { ($0.element, $0.offset) })
        return items.sorted { a, b in
            let ra = layerRank(for: a.categoryName)
            let rb = layerRank(for: b.categoryName)
            if ra != rb { return ra < rb }
            return (orderIndex[a.id] ?? 0) < (orderIndex[b.id] ?? 0)
        }
    }
}

// MARK: - View

/// Fashion-style summary of up to three pieces; balances space when fewer items exist.
struct OutfitPreviewView: View {
    var items: [OutfitPreviewItem]
    var outfitItemOrder: [UUID]

    private var pieces: [OutfitPreviewItem] {
        Array(OutfitPreviewComposition.sorted(items, outfitOrder: outfitItemOrder).prefix(3))
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Group {
                switch pieces.count {
                case 0:
                    emptyState
                case 1:
                    singlePiece(pieces[0], in: size)
                case 2:
                    twoPieces(pieces[0], pieces[1], in: size)
                default:
                    threePieces(pieces[0], pieces[1], pieces[2], in: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private var emptyState: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 34, weight: .medium))
            .foregroundStyle(.white.opacity(0.42))
            .symbolRenderingMode(.hierarchical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func singlePiece(_ item: OutfitPreviewItem, in size: CGSize) -> some View {
        let side = min(size.width * 0.78, size.height * 0.72)
        return VStack {
            Spacer(minLength: size.height * 0.06)
            previewImageCell(item, maxSide: side)
            Spacer(minLength: size.height * 0.06)
        }
    }

    private func twoPieces(_ first: OutfitPreviewItem, _ second: OutfitPreviewItem, in size: CGSize) -> some View {
        let topSide = min(size.width * 0.72, size.height * 0.44)
        let bottomSide = min(size.width * 0.66, size.height * 0.38)
        return VStack(spacing: size.height * 0.045) {
            Spacer(minLength: size.height * 0.04)
            previewImageCell(first, maxSide: topSide)
            previewImageCell(second, maxSide: bottomSide)
            Spacer(minLength: size.height * 0.04)
        }
    }

    private func threePieces(_ a: OutfitPreviewItem, _ b: OutfitPreviewItem, _ c: OutfitPreviewItem, in size: CGSize) -> some View {
        let topSide = min(size.width * 0.70, size.height * 0.34)
        let midSide = min(size.width * 0.62, size.height * 0.28)
        let accentSide = min(size.width * 0.40, size.height * 0.22)
        return VStack(spacing: size.height * 0.03) {
            Spacer(minLength: size.height * 0.03)
            previewImageCell(a, maxSide: topSide)
            previewImageCell(b, maxSide: midSide)
            HStack(spacing: size.width * 0.05) {
                Spacer(minLength: 0)
                previewImageCell(c, maxSide: accentSide)
                Spacer(minLength: 0)
            }
            Spacer(minLength: size.height * 0.03)
        }
    }

    @ViewBuilder
    private func previewImageCell(_ item: OutfitPreviewItem, maxSide: CGFloat) -> some View {
        let url = ClothingImageStorage.fileURL(fileName: item.thumbnailFileName)
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: maxSide, maxHeight: maxSide)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 5)
                    .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
            case .empty:
                ProgressView()
                    .frame(width: maxSide, height: maxSide)
            case .failure:
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: maxSide, height: maxSide)
            @unknown default:
                EmptyView()
            }
        }
    }
}

#Preview("OutfitPreviewView — empty") {
    ZStack {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.75, green: 0.88, blue: 0.98),
                        Color(red: 0.55, green: 0.82, blue: 0.75),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        OutfitPreviewView(items: [], outfitItemOrder: [])
            .padding(14)
    }
    .aspectRatio(0.78, contentMode: .fit)
    .padding()
    .background(AppTheme.background)
}
