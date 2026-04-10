//
//  CircularIconButton.swift
//  PEPLOS
//

import SwiftUI

enum CircularIconButtonStyle {
    case search
    case add
    case settings
}

struct CircularIconButton: View {
    let style: CircularIconButtonStyle
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: style == .add ? 20 : 18, weight: style == .add ? .bold : .medium))
                .foregroundStyle(style == .add ? Color.white : Color.primary)
                .frame(width: 48, height: 48)
                .background(buttonBackground)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(style == .add ? Color.white.opacity(0.28) : Color.white.opacity(0.72), lineWidth: 1)
                }
                .overlay(alignment: .top) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.42),
                                    Color.white.opacity(0.02),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(1)
                        .blendMode(.screen)
                }
                .shadow(color: style == .add ? AppTheme.accent.opacity(0.28) : .black.opacity(0.08), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
    }

    private var iconName: String {
        switch style {
        case .add: return "plus"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape.fill"
        }
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(style == .add ? AppTheme.accent.opacity(0.22) : Color.white.opacity(0.18))
                .glassEffect(glassStyle, in: Circle())
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .fill(fallbackTint)
                }
        }
    }

    @available(iOS 26.0, *)
    private var glassStyle: Glass {
        switch style {
        case .search, .settings:
            return .regular.interactive()
        case .add:
            return .regular.tint(AppTheme.accent.opacity(0.72)).interactive()
        }
    }

    private var fallbackTint: AnyShapeStyle {
        switch style {
        case .search, .settings:
            return AnyShapeStyle(Color.white.opacity(0.30))
        case .add:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(0.96),
                        AppTheme.accentSecondary.opacity(0.82),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        CircularIconButton(style: .search)
        CircularIconButton(style: .add)
        CircularIconButton(style: .settings)
    }
    .padding()
    .background(AppTheme.background)
}
