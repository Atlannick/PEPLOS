//
//  FirstLaunchGuideView.swift
//  PEPLOS
//

import SwiftUI

struct FirstLaunchGuideView: View {
    struct Slide: Identifiable {
        let id: Int
        let title: String
        let subtitle: String
        let systemImage: String
    }

    let onFinish: () -> Void

    @State private var selectedIndex = 0

    private let slides: [Slide] = [
        .init(
            id: 0,
            title: "Welcome to PEPLOS",
            subtitle: "Peplos helps you discover great outfit combinations even if you are not at home. It's your closet in your pocket.",
            systemImage: ""
        ),
        .init(
            id: 1,
            title: "Add clothes to your closet",
            subtitle: "Start by adding your pieces so Peplos knows what you can wear.",
            systemImage: "hanger"
        ),
        .init(
            id: 2,
            title: "Build Outfit",
            subtitle: "Build and save looks from your closet for quick daily decisions.",
            systemImage: "heart"
        ),
        .init(
            id: 3,
            title: "Let Lucky Look suggest combinations",
            subtitle: "Get fresh outfit ideas based on your saved wardrobe anytime you want.",
            systemImage: "dice.fill"
        )
    ]

    private var isLastSlide: Bool {
        selectedIndex == slides.count - 1
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                ForEach(slides) { slide in
                    if slide.id == selectedIndex {
                        guidePage(slide)
                            .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.45), value: selectedIndex)

            HStack(spacing: 8) {
                ForEach(slides) { slide in
                    Circle()
                        .fill(slide.id == selectedIndex ? AppTheme.accent : Color.primary.opacity(0.14))
                        .frame(width: 8, height: 8)
                }
            }

            Button(action: primaryAction) {
                Text(primaryButtonTitle)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(AppTheme.accent)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(AppTheme.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func guidePage(_ slide: Slide) -> some View {
        if slide.id == 0 {
            welcomePage(slide)
        } else {
            infoPage(slide)
        }
    }

    private var primaryButtonTitle: String {
        if selectedIndex == 0 {
            return "Get Started"
        }
        if isLastSlide {
            return "Finish"
        }
        return "Next"
    }

    private func welcomePage(_ slide: Slide) -> some View {
        ZStack {
            pageGradient(for: slide.id)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            VStack(spacing: 18) {
                Spacer(minLength: 8)

                AppLogoMark()

                Text("WELCOME TO PEPLOS")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text(slide.subtitle)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.94))
                    .padding(.horizontal, 12)

                Spacer(minLength: 8)
            }
            .padding(26)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.26, green: 0.48, blue: 0.84).opacity(0.28), radius: 22, x: 0, y: 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func infoPage(_ slide: Slide) -> some View {
        ZStack {
            pageGradient(for: slide.id)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            VStack(spacing: 18) {
                Spacer(minLength: 12)

                Image(systemName: slide.systemImage)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 112, height: 112)
                    .background(.white.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                    }

                Text(slide.title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)

                Text(slide.subtitle)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.94))
                    .padding(.horizontal, 10)

                if slide.id == 3 {
                    Text("Lucky Look analyzes your wardrobe, color harmony, weather, and style balance to suggest outfits every time you tap it.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.white.opacity(0.84))
                        .padding(.horizontal, 14)
                        .padding(.top, 2)
                }

                Spacer(minLength: 12)
            }
            .padding(26)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.26, green: 0.48, blue: 0.84).opacity(0.28), radius: 22, x: 0, y: 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pageGradient(for slideID: Int) -> LinearGradient {
        switch slideID {
        case 0:
            // Welcome
            return LinearGradient(
                colors: [
                    Color(red: 0.66, green: 0.82, blue: 1.0),
                    Color(red: 0.52, green: 0.73, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 1:
            // Add clothes
            return LinearGradient(
                colors: [
                    Color(red: 0.70, green: 0.93, blue: 0.82),
                    Color(red: 0.52, green: 0.82, blue: 0.68)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 2:
            // Build outfit
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.86, blue: 0.73),
                    Color(red: 0.96, green: 0.70, blue: 0.52)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            // Lucky look
            return LinearGradient(
                colors: [
                    Color(red: 0.89, green: 0.80, blue: 0.98),
                    Color(red: 0.75, green: 0.61, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func primaryAction() {
        if isLastSlide {
            onFinish()
        } else {
            selectedIndex += 1
        }
    }

}

private struct AppLogoMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.23, green: 0.43, blue: 0.99),
                        Color(red: 0.21, green: 0.27, blue: 0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 112, height: 112)
            .overlay {
                Image(systemName: "tshirt.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 8)
    }
}

#Preview {
    FirstLaunchGuideView(onFinish: {})
}
