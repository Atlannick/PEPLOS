//
//  CategoryItemPickerSheet.swift
//  PEPLOS
//

import SwiftUI

struct CategoryItemPickerSheet: View {
    let category: ClothingCategory
    let items: [ClosetItem]
    let onPick: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    PepEmptyState(systemImage: "photo", message: "No photos in this category")
                        .padding(.top, 40)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(items) { item in
                                Button {
                                    onPick(item.id)
                                } label: {
                                    ClothingCard(item: item, showDate: true, fixedWidth: nil)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
