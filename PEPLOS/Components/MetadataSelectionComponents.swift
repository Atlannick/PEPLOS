//
//  MetadataSelectionComponents.swift
//  PEPLOS
//
//  Shared chips and sections for the Add Item metadata form.
//

import SwiftUI

// MARK: - Section container

struct MetadataFormCard<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary.opacity(0.78))
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtitleGray)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .pepCardShadow()
    }
}

// MARK: - Fashion item category

extension FashionItemCategory {
    /// Categories available in Add Item metadata (engine slot).
    static let addItemPickerCases: [FashionItemCategory] = [
        .top, .bottom, .shoes, .dress, .outerwear, .accessory, .hat,
    ]

    var addItemPickerTitle: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        case .shoes: return "Shoes"
        case .dress: return "Dress"
        case .outerwear: return "Outerwear"
        case .accessory: return "Accessory"
        case .hat: return "Hat"
        case .bag, .layer:
            return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}

extension FashionSeason {
    var addItemPickerTitle: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .autumn: return "Autumn"
        case .winter: return "Winter"
        }
    }
}

struct FashionItemCategoryChipGrid: View {
    @Binding var selection: FashionItemCategory?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
            ForEach(FashionItemCategory.addItemPickerCases, id: \.self) { cat in
                let selected = selection == cat
                Button {
                    selection = cat
                } label: {
                    Text(cat.addItemPickerTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(selected ? AppTheme.accent : AppTheme.chipInactive)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Primary color

struct FashionColorChipGrid: View {
    @Binding var selection: FashionColor?
    let palette: [FashionColor]

    private let columns = [
        GridItem(.adaptive(minimum: 88), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
            ForEach(palette, id: \.self) { color in
                let selected = selection == color
                Button {
                    selection = color
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color.addItemSwatchColor)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                            }
                        Text(color.addItemDisplayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(selected ? AppTheme.accent : AppTheme.chipInactive)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Optional multi-select tags

struct MetadataMultiSelectGrid<T: Hashable>: View {
    let options: [T]
    @Binding var selection: Set<T>
    var titleFor: (T) -> String

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
            ForEach(options, id: \.self) { option in
                let on = selection.contains(option)
                Button {
                    if on {
                        selection.remove(option)
                    } else {
                        selection.insert(option)
                    }
                } label: {
                    Text(titleFor(option))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(on ? Color.white : Color.primary.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .padding(.horizontal, 8)
                        .background(on ? AppTheme.accent : AppTheme.chipInactive)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Occasion labels

enum AddItemOccasionOption: String, CaseIterable, Identifiable {
    case everyday
    case casual
    case smartCasual
    case businessCasual
    case formal
    case evening
    case sporty
    case vacation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everyday: return "Everyday"
        case .casual: return "Casual"
        case .smartCasual: return "Smart Casual"
        case .businessCasual: return "Business Casual"
        case .formal: return "Formal"
        case .evening: return "Evening"
        case .sporty: return "Sporty"
        case .vacation: return "Vacation"
        }
    }

    var engineValue: FashionOccasion {
        switch self {
        case .everyday: return .everyday
        case .casual: return .casual
        case .smartCasual: return .smartCasual
        case .businessCasual: return .businessCasual
        case .formal: return .formal
        case .evening: return .evening
        case .sporty: return .sporty
        case .vacation: return .vacationBeach
        }
    }
}

// MARK: - Style tag options (subset of FashionStyleTag)

enum AddItemStyleOption: String, CaseIterable, Identifiable {
    case minimal
    case classic
    case streetwear
    case sporty
    case elegant
    case smartCasual
    case relaxed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .minimal: return "Minimal"
        case .classic: return "Classic"
        case .streetwear: return "Streetwear"
        case .sporty: return "Sporty"
        case .elegant: return "Elegant"
        case .smartCasual: return "Smart Casual"
        case .relaxed: return "Relaxed"
        }
    }

    var engineValue: FashionStyleTag {
        switch self {
        case .minimal: return .minimal
        case .classic: return .classic
        case .streetwear: return .streetwear
        case .sporty: return .sporty
        case .elegant: return .elegant
        case .smartCasual: return .smartCasual
        case .relaxed: return .relaxed
        }
    }
}
