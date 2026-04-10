//
//  MainTabBar.swift
//  PEPLOS
//

import SwiftUI

struct MainTabBar: View {
    @Binding var selection: MainTab
    @Namespace private var selectionAnimation

    private let animation = Animation.snappy(duration: 0.42, extraBounce: 0.14)

    /// Sized to mimic the App Store floating island tab bar.
    private let iconSize: CGFloat = 20
    private let labelSize: CGFloat = 11
    private let rowHeight: CGFloat = 64

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tabBarBackground)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .animation(animation, value: selection)
    }

    @ViewBuilder
    private func tabButton(for tab: MainTab) -> some View {
        let selected = selection == tab

        Button {
            withAnimation(animation) {
                selection = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: iconSize, weight: selected ? .semibold : .regular))
                    .symbolVariant(.none)
                    .scaleEffect(1.0)

                Text(tab.title)
                    .font(.system(size: labelSize, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(selected ? Color(red: 0.09, green: 0.46, blue: 1.0) : Color.black.opacity(0.62))
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
            .background {
                if selected {
                    selectionBackground()
                        .matchedGeometryEffect(id: "selected-tab-background", in: selectionAnimation)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab == .settings ? "Settings" : tab.title)
    }

    @ViewBuilder
    private func selectionBackground() -> some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color(red: 0.08, green: 0.45, blue: 1.0).opacity(0.14))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color(red: 0.08, green: 0.45, blue: 1.0).opacity(0.26), lineWidth: 1)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
    }

    private var tabBarBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 27, style: .continuous)

        return shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape
                    .strokeBorder(Color.white.opacity(0.88), lineWidth: 0.9)
            }
            .overlay(alignment: .top) {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.62),
                                Color.white.opacity(0.14),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .padding(0.7)
                    .blendMode(.screen)
            }
            .shadow(color: .black.opacity(0.16), radius: 20, x: 0, y: 10)
            .shadow(color: Color.white.opacity(0.36), radius: 8, x: 0, y: -2)
            .shadow(color: .black.opacity(0.24), radius: 28, x: 0, y: 16)
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var tab = MainTab.home
        var body: some View {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack {
                    Spacer()
                    MainTabBar(selection: $tab)
                }
            }
        }
    }
    return PreviewHost()
}
