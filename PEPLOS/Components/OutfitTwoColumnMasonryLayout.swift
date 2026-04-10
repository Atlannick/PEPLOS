//
//  OutfitTwoColumnMasonryLayout.swift
//  PEPLOS
//

import SwiftUI

/// Two columns, top-aligned: each new card is placed under the **shorter** column so different heights stagger naturally with even gaps.
struct OutfitTwoColumnMasonryLayout: Layout {
    var horizontalSpacing: CGFloat = 14
    var verticalSpacing: CGFloat = 14

    struct CacheData {
        var frames: [CGRect] = []
        var size: CGSize = .zero
    }

    func makeCache(subviews: Subviews) -> CacheData {
        CacheData()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions(by: CGSize(width: 375, height: 1)).width
        compute(width: width, subviews: subviews, cache: &cache)
        return cache.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        compute(width: bounds.width, subviews: subviews, cache: &cache)
        for index in subviews.indices {
            let frame = cache.frames[index]
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func compute(width: CGFloat, subviews: Subviews, cache: inout CacheData) {
        guard !subviews.isEmpty else {
            cache.frames = []
            cache.size = CGSize(width: width, height: 0)
            return
        }

        let columnWidth = max(0, (width - horizontalSpacing) / 2)
        var leftY: CGFloat = 0
        var rightY: CGFloat = 0
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)

        for subview in subviews {
            let measured = subview.sizeThatFits(
                ProposedViewSize(width: columnWidth, height: nil)
            )
            let h = measured.height

            if leftY <= rightY {
                if leftY > 0 { leftY += verticalSpacing }
                frames.append(CGRect(x: 0, y: leftY, width: columnWidth, height: h))
                leftY += h
            } else {
                if rightY > 0 { rightY += verticalSpacing }
                frames.append(
                    CGRect(x: columnWidth + horizontalSpacing, y: rightY, width: columnWidth, height: h)
                )
                rightY += h
            }
        }

        cache.frames = frames
        cache.size = CGSize(width: width, height: max(leftY, rightY))
    }
}
