//
//  HomeSummaryCard.swift
//  PEPLOS
//

import SwiftUI

struct HomeSummaryCard: View {
    var totalItems: Int = 3
    var onAddItem: () -> Void = {}
    var onBuildOutfit: () -> Void = {}

    private let gradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.38, blue: 1.0),
            AppTheme.accent,
            Color(red: 0.14, green: 0.31, blue: 0.98),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    glassInfoPill

                    Text("\(totalItems)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                iconBadge
            }

            HStack(spacing: 12) {
                actionButton(title: "Add Item", systemImage: "plus", action: onAddItem)
                actionButton(title: "Build Outfit", systemImage: "heart.fill", action: onBuildOutfit)
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
        .shadow(color: AppTheme.accent.opacity(0.18), radius: 22, x: 0, y: 14)
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    private var glassInfoPill: some View {
        Text("Total Items")
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

    private var iconBadge: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.white.opacity(0.16))
            .frame(width: 58, height: 58)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            }
            .overlay {
                Image(systemName: "tshirt.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    @ViewBuilder
    private func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
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
                .fill(gradient.opacity(0.58))
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    AppTheme.accent.opacity(0.16),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .glassEffect(.regular.tint(AppTheme.accent.opacity(0.48)), in: shape)
        } else {
            shape
                .fill(gradient)
                .overlay {
                    shape
                        .fill(.ultraThinMaterial.opacity(0.10))
                }
        }
    }
}

#Preview {
    HomeSummaryCard()
        .padding()
        .background(AppTheme.background)
}
