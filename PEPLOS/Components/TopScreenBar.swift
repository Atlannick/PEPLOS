//
//  TopScreenBar.swift
//  PEPLOS
//

import SwiftUI

struct TopScreenBar: View {
    var title: String?
    var titleGradientColors: [Color] = [
        Color.primary,
        AppTheme.accent.opacity(0.72),
    ]
    /// Home greeting uses 34; tab headers use a slightly smaller size.
    var titlePointSize: CGFloat = 34
    /// When `true`, the title is centered in the bar (e.g. Home greeting).
    var centerTitle: Bool = false
    var leadingActionTitle: String?
    var onLeadingAction: () -> Void = {}
    /// Optional trailing text button (e.g. Settings **Save**). Shown before the add button when set.
    var trailingActionTitle: String?
    var onTrailingAction: () -> Void = {}
    /// When `true`, `trailingActionTitle` uses green foreground (primary Save affordance).
    var trailingActionUsesGreenAccent: Bool = false
    /// When `false`, the trailing add button is hidden (e.g. Home).
    var showsAddButton: Bool = true
    var onAdd: () -> Void = {}

    var body: some View {
        Group {
            if centerTitle, let title {
                ZStack(alignment: .top) {
                    titleLabel(title)
                        .frame(maxWidth: .infinity)

                    HStack {
                        if let leadingActionTitle {
                            leadingActionButton(leadingActionTitle)
                        }

                        Spacer(minLength: 0)

                        if let trailingActionTitle {
                            trailingActionButton(trailingActionTitle)
                        }

                        if showsAddButton {
                            CircularIconButton(style: .add, action: onAdd)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                ZStack(alignment: .top) {
                    if let title {
                        titleLabel(title)
                            .frame(maxWidth: .infinity)
                    }

                    HStack(alignment: .top) {
                        if let leadingActionTitle {
                            leadingActionButton(leadingActionTitle)
                        }

                        Spacer(minLength: 0)

                        if let trailingActionTitle {
                            trailingActionButton(trailingActionTitle)
                        }

                        if showsAddButton {
                            CircularIconButton(style: .add, action: onAdd)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func leadingActionButton(_ title: String) -> some View {
        capsuleToolbarButton(title, foreground: AppTheme.accent, action: onLeadingAction)
    }

    private func trailingActionButton(_ title: String) -> some View {
        capsuleToolbarButton(
            title,
            foreground: trailingActionUsesGreenAccent ? Color.green : AppTheme.accent,
            action: onTrailingAction
        )
    }

    private func capsuleToolbarButton(_ title: String, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, 18)
                .frame(height: 48)
                .background(buttonBackground)
                .clipShape(Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.18))
                .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        } else {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.30))
                }
        }
    }

    private func titleLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: titlePointSize, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: titleGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .multilineTextAlignment(centerTitle ? .center : .leading)
            .padding(.horizontal, centerTitle ? 18 : 0)
            .padding(.vertical, 10)
            .background {
                if centerTitle {
                    Capsule(style: .continuous)
                        .fill(.white.opacity(0.44))
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
                        }
                        .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: -2)
                }
            }
    }
}

/// Compact local weather for the home screen header (uses shared `StylistWeatherController`).
struct HomeWeatherChip: View {
    @EnvironmentObject private var weather: StylistWeatherController

    var body: some View {
        Group {
            if !weather.weatherLine.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: weather.weatherSymbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityLabel("Current weather")
                    Text(weather.weatherLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            } else if !weather.statusLine.isEmpty {
                Text(weather.statusLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.subtitleGray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            } else {
                Text("—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.subtitleGray)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        /// Wide enough for “17°C · Clear” without truncating to an ellipsis; still scales down on narrow layouts.
        .frame(maxWidth: 280, alignment: .center)
        .background {
            Capsule(style: .continuous)
                .fill(.white.opacity(0.44))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: -2)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack {
            Spacer(minLength: 0)
            HomeWeatherChip()
            Spacer(minLength: 0)
        }
        TopScreenBar(title: "Good Morning", centerTitle: true, showsAddButton: false)
        TopScreenBar(title: "With add")
        TopScreenBar(title: "Editable", leadingActionTitle: "Edit")
        TopScreenBar(title: .none, showsAddButton: false)
    }
    .padding()
    .background(AppTheme.background)
    .environmentObject(StylistWeatherController())
}
