//
//  StylistView.swift
//  PEPLOS
//

import SwiftUI

struct StylistView: View {
    /// Set to `false` when the AI stylist should accept occasion input again.
    private static let occasionFieldTemporarilyDisabled = true

    @EnvironmentObject private var weatherController: StylistWeatherController
    @State private var occasion = ""
    @State private var aiButtonShimmerProgress: CGFloat = -0.5
    @State private var aiButtonShimmerTask: Task<Void, Never>?

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.42, blue: 1.0),
                Color(red: 0.48, green: 0.28, blue: 0.88),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var goldenButtonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.86, blue: 0.38),
                Color(red: 0.90, green: 0.62, blue: 0.12),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var stylistGlassTint: Color {
        Color(red: 0.38, green: 0.30, blue: 0.92)
    }

    /// Drop shadow metrics for the main AI card (notice card uses larger radii / stronger opacity).
    private static let aiCardShadowPrimary = (radius: CGFloat(22), y: CGFloat(14))
    private static let aiCardShadowSecondary = (color: Color.black.opacity(0.08), radius: CGFloat(18), y: CGFloat(10))

    private var comingSoonNoticeGreen: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.78, blue: 0.52),
                Color(red: 0.10, green: 0.58, blue: 0.42),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TopScreenBar(
                    title: nil,
                    titleGradientColors: AppTheme.screenHeaderTitleGradientColors,
                    titlePointSize: 28,
                    centerTitle: true,
                    showsAddButton: false
                )

                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            stylistInfoPill

                            Text("Outfit ideas")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.85)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        stylistIconBadge
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("CURRENT WEATHER")

                        HStack(spacing: 10) {
                            Image(systemName: weatherController.weatherLine.isEmpty ? "location.circle.fill" : weatherController.weatherSymbolName)
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.95))
                                .accessibilityLabel(weatherController.weatherLine.isEmpty ? "Location" : "Current weather")

                            VStack(alignment: .leading, spacing: 4) {
                                if !weatherController.weatherLine.isEmpty {
                                    Text(weatherController.weatherLine)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.white)
                                } else if !weatherController.statusLine.isEmpty {
                                    Text(weatherController.statusLine)
                                        .font(.body)
                                        .foregroundStyle(.white.opacity(0.82))
                                } else {
                                    Text("—")
                                        .font(.body)
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background { glassInsetShape(cornerRadius: 18) }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("WHAT'S THE OCCASION?")

                        TextField(
                            "",
                            text: $occasion,
                            prompt: Text("e.g. Job Interview, Beach Day, Gym")
                                .foregroundStyle(.white.opacity(0.42))
                        )
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .disabled(Self.occasionFieldTemporarilyDisabled)
                        .opacity(Self.occasionFieldTemporarilyDisabled ? 0.5 : 1)
                        .padding(16)
                        .background { glassInsetShape(cornerRadius: 18) }
                    }

                    Button {
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(goldenButtonGradient)

                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.clear)
                                .overlay {
                                    aiButtonDiagonalShimmer(progress: aiButtonShimmerProgress)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .allowsHitTesting(false)

                            HStack(spacing: 8) {
                                Text("Get AI Suggestion")
                                Image(systemName: "sparkles")
                                    .symbolEffect(.pulse, options: .repeating.speed(0.35))
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.22, green: 0.14, blue: 0.06))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                        }
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                        }
                        .shadow(color: Color(red: 0.55, green: 0.35, blue: 0.05).opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(22)
                .background { stylistCardBackground }
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
                .shadow(color: stylistGlassTint.opacity(0.22), radius: Self.aiCardShadowPrimary.radius, x: 0, y: Self.aiCardShadowPrimary.y)
                .shadow(color: Self.aiCardShadowSecondary.color, radius: Self.aiCardShadowSecondary.radius, x: 0, y: Self.aiCardShadowSecondary.y)

                VStack(alignment: .center, spacing: 12) {
                    Text("AI Stylist is coming soon!")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Soon PEPLOS will suggest outfits based on your wardrobe, weather, and occasion.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.94))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 18)
                .background(comingSoonNoticeGreen)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 1.5)
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    Color.white.opacity(0.04),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(1)
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
                .shadow(color: Color(red: 0.05, green: 0.45, blue: 0.28).opacity(0.42), radius: 36, x: 0, y: 22)
                .shadow(color: .black.opacity(0.12), radius: 28, x: 0, y: 18)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            weatherController.startIfNeeded()
            startAiButtonShimmerLoop()
        }
        .onDisappear {
            aiButtonShimmerTask?.cancel()
            aiButtonShimmerTask = nil
        }
    }

    /// 45° diagonal highlight sweep; `progress` moves the band across the button (unit space along the diagonal).
    @ViewBuilder
    private func aiButtonDiagonalShimmer(progress: CGFloat) -> some View {
        GeometryReader { _ in
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.62), location: 0.5),
                    .init(color: .clear, location: 1),
                ],
                startPoint: UnitPoint(x: progress - 0.36, y: progress - 0.36),
                endPoint: UnitPoint(x: progress + 0.36, y: progress + 0.36)
            )
            .blendMode(.screen)
        }
    }

    private func startAiButtonShimmerLoop() {
        aiButtonShimmerTask?.cancel()
        aiButtonShimmerTask = Task { @MainActor in
            aiButtonShimmerProgress = -0.5
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7))
                guard !Task.isCancelled else { break }
                withAnimation(.linear(duration: 2)) {
                    aiButtonShimmerProgress = 1.45
                }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                var reset = Transaction()
                reset.disablesAnimations = true
                withTransaction(reset) {
                    aiButtonShimmerProgress = -0.5
                }
            }
        }
    }

    private var stylistInfoPill: some View {
        Text("Personalized")
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

    private var stylistIconBadge: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.white.opacity(0.16))
            .frame(width: 58, height: 58)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            }
            .overlay {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.72))
            .tracking(0.8)
    }

    @ViewBuilder
    private func glassInsetShape(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.white.opacity(0.16))
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                shape
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

    @ViewBuilder
    private var stylistCardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        if #available(iOS 26.0, *) {
            shape
                .fill(cardGradient.opacity(0.58))
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    stylistGlassTint.opacity(0.22),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .glassEffect(.regular.tint(stylistGlassTint.opacity(0.42)), in: shape)
        } else {
            shape
                .fill(cardGradient)
                .overlay {
                    shape
                        .fill(.ultraThinMaterial.opacity(0.10))
                }
        }
    }
}

#Preview {
    StylistView()
        .environmentObject(StylistWeatherController())
}
