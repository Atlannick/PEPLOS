//
//  LuckyLookHomeSection.swift
//  PEPLOS
//

import SwiftUI

struct LuckyLookHomeSection: View {
    @EnvironmentObject private var closet: ClosetStore

    /// True when the closet has at least one clothing row (any category).
    let hasClothingItems: Bool
    /// Persisted latest look, if valid.
    let snapshot: LuckyLookSnapshot?
    /// Whether the user may tap “Get Lucky Look”.
    let canGenerateNew: Bool
    let isLoading: Bool
    var onRequestLuckyLook: () -> Void
    /// Opens the full Lucky Look result (preview + actions).
    var onOpenLuckyLook: () -> Void
    var onAddItem: () -> Void

    private let gradient = LinearGradient(
        colors: [
            Color(red: 0.14, green: 0.42, blue: 0.38),
            Color(red: 0.10, green: 0.36, blue: 0.34),
            Color(red: 0.12, green: 0.40, blue: 0.44),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let glassTint = Color(red: 0.08, green: 0.32, blue: 0.30)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    glassInfoPill

                    Text("Lucky Look")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.75)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "dice.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    }
            }

            mainBody

            if shouldShowGetButton {
                getLuckyLookButton
            }
        }
        .padding(22)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.34),
                            Color.white.opacity(0.02),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(1)
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .shadow(color: glassTint.opacity(0.22), radius: 22, x: 0, y: 14)
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private var shouldShowGetButton: Bool {
        hasClothingItems && canGenerateNew && !isLoading
    }

    @ViewBuilder
    private var mainBody: some View {
        if !hasClothingItems {
            VStack(alignment: .leading, spacing: 16) {
                Text("No clothing items yet.\nAdd items to your closet to unlock Lucky Look.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onAddItem) {
                    Text("Add Item")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.12, green: 0.38, blue: 0.36))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.white)
                        }
                }
                .buttonStyle(.plain)
            }
        } else if isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.15)
                    .tint(.white)

                Text("Styling your look…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else if let snap = snapshot {
            revealedContent(snap: snap)
        } else {
            Text("Get a fresh outfit built from your closet using Peplos styling rules. You can generate a new Lucky Look any time.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func revealedContent(snap: LuckyLookSnapshot) -> some View {
        let previewItems = closet.outfitPreviewItems(forItemIds: snap.itemIds)

        Button(action: onOpenLuckyLook) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.08),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    OutfitPreviewView(items: previewItems, outfitItemOrder: snap.itemIds)
                        .padding(14)
                }
                .aspectRatio(0.85, contentMode: .fit)

                Text("Tap to open")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var glassInfoPill: some View {
        Text("Shuffle your Closet")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.14))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    }
            }
    }

    private var getLuckyLookButton: some View {
        Button(action: onRequestLuckyLook) {
            HStack(spacing: 10) {
                Text("Get a Lucky Look")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.30),
                                        Color.white.opacity(0.03),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(1)
                            .blendMode(.screen)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        if #available(iOS 26.0, *) {
            shape
                .fill(gradient)
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    glassTint.opacity(0.12),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .glassEffect(.regular.tint(glassTint.opacity(0.35)), in: shape)
        } else {
            shape
                .fill(gradient)
                .overlay {
                    shape
                        .fill(.ultraThinMaterial.opacity(0.06))
                }
        }
    }
}

#Preview("Lucky Look — request") {
    LuckyLookHomeSection(
        hasClothingItems: true,
        snapshot: nil,
        canGenerateNew: true,
        isLoading: false,
        onRequestLuckyLook: {},
        onOpenLuckyLook: {},
        onAddItem: {}
    )
    .environmentObject(ClosetStore())
    .padding()
    .background(AppTheme.background)
}

#Preview("Lucky Look — loading") {
    LuckyLookHomeSection(
        hasClothingItems: true,
        snapshot: nil,
        canGenerateNew: true,
        isLoading: true,
        onRequestLuckyLook: {},
        onOpenLuckyLook: {},
        onAddItem: {}
    )
    .environmentObject(ClosetStore())
    .padding()
    .background(AppTheme.background)
}
