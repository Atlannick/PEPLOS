//
//  ClosetView.swift
//  PEPLOS
//

import SwiftUI

struct ClosetView: View {
    @EnvironmentObject private var closet: ClosetStore
    @State private var category = "All"
    @State private var isEditingCategories = false
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var photoDetailItem: ClosetItem?
    @State private var categoryPendingDelete: String?

    private var categories: [String] {
        ["All"] + closet.visibleCategoryNames
    }

    /// “All” shows one tile per category; a specific chip lists that category’s items.
    private var gridItems: [ClosetItem] {
        if category == "All" {
            closet.categoryShelfItems(sortedByRecentActivity: false)
        } else {
            closet.items(filteredBy: category)
        }
    }

    private var showsCategoryEmptyState: Bool {
        category != "All" && gridItems.isEmpty
    }

    private var showsAllEmptyState: Bool {
        category == "All" && closet.visibleCategoryNames.isEmpty
    }

    private let grid = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    private var showsCategoryLinkGradient: Bool {
        category != "All"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                TopScreenBar(
                    title: nil,
                    titleGradientColors: AppTheme.screenHeaderTitleGradientColors,
                    titlePointSize: 28,
                    leadingActionTitle: closet.visibleCategoryNames.isEmpty ? nil : (isEditingCategories ? "Done" : "Edit"),
                    onLeadingAction: {
                        isEditingCategories.toggle()
                    },
                    onAdd: {
                        showAddCategory = true
                    }
                )

                ChipSelector(
                    categories: categories,
                    selection: $category,
                    isEditing: isEditingCategories,
                    isDeletable: { $0 != "All" },
                    onMoveCategory: { source, destination in
                        closet.moveCategory(named: source, before: destination)
                    },
                    onRequestDelete: { categoryPendingDelete = $0 }
                )
                .id(isEditingCategories)

                if showsAllEmptyState {
                    PepEmptyState(
                        systemImage: "tshirt",
                        message: "No categories yet"
                    )
                    .padding(.top, 56)
                    .padding(.bottom, 24)
                } else if showsCategoryEmptyState {
                    PepEmptyState(
                        systemImage: "tshirt",
                        message: "No items in this category"
                    )
                    .padding(.top, 56)
                    .padding(.bottom, 24)
                } else {
                    LazyVGrid(columns: grid, spacing: 18) {
                        ForEach(gridItems) { item in
                            ClothingCard(
                                item: item,
                                showDate: category != "All",
                                fixedWidth: nil
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard item.hasPhoto else { return }
                                if category == "All" {
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                                        category = item.category
                                    }
                                } else {
                                    photoDetailItem = item
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: category)
        .background {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if showsCategoryLinkGradient {
                    LinearGradient(
                        colors: [
                            AppTheme.accent.opacity(0.20),
                            AppTheme.accent.opacity(0.10),
                            AppTheme.accent.opacity(0.04),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
        }
        .onChange(of: categories) { _, newCategories in
            if !newCategories.contains(category) {
                category = "All"
            }

            if closet.visibleCategoryNames.isEmpty {
                isEditingCategories = false
            }
        }
        .fullScreenCover(item: $photoDetailItem, onDismiss: { photoDetailItem = nil }) { item in
            ClothingPhotoDetailView(item: item)
                .environmentObject(closet)
        }
        .alert("Add Category", isPresented: $showAddCategory) {
            TextField("Category Name", text: $newCategoryName)
            Button("Cancel", role: .cancel) {
                newCategoryName = ""
            }
            Button("Add") {
                if let addedCategory = closet.addCategory(newCategoryName) {
                    category = addedCategory
                }
                newCategoryName = ""
            }
        } message: {
            Text("Create a category for your closet.")
        }
        .confirmationDialog(
            "Delete category?",
            isPresented: Binding(
                get: { categoryPendingDelete != nil },
                set: { if !$0 { categoryPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let name = categoryPendingDelete {
                    closet.removeCategory(named: name)
                    if category == name {
                        category = "All"
                    }
                }
                categoryPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                categoryPendingDelete = nil
            }
        } message: {
                if let name = categoryPendingDelete {
                let count = closet.itemRowCount(inCategoryNamed: name)
                if count > 0 {
                    Text("“\(name)” has \(count) item(s). They will be removed too.")
                } else {
                    Text("Remove “\(name)” from your closet?")
                }
            }
        }
    }
}

#Preview {
    ClosetView()
        .environmentObject(ClosetStore())
}
