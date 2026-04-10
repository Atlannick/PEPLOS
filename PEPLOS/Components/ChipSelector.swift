//
//  ChipSelector.swift
//  PEPLOS
//

import SwiftUI
import UniformTypeIdentifiers

struct ChipSelector: View {
    let categories: [String]
    @Binding var selection: String
    var isEditing: Bool = false
    var isDeletable: (String) -> Bool = { _ in false }
    var onMoveCategory: ((String, String) -> Void)?
    var onRequestDelete: ((String) -> Void)?
    @State private var draggedCategory: String?
    @State private var pressedCategory: String?
    @State private var isWiggling = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                    let isSelected = selection == category
                    let chipContent = chipLabel(
                        for: category,
                        isSelected: isSelected,
                        showsDeleteButton: pressedCategory != category
                    )
                    Button {
                        guard !isEditing else { return }
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                            selection = category
                        }
                    } label: {
                        chipContent
                    }
                    .buttonStyle(.plain)
                    .padding(.top, isEditing && isDeletable(category) ? 10 : 0)
                    .padding(.leading, isEditing && isDeletable(category) ? 6 : 0)
                    .rotationEffect(wiggleAngle(for: index))
                    .animation(
                        isEditing
                        ? .easeInOut(duration: 0.16).repeatForever(autoreverses: true).delay(Double(index) * 0.03)
                        : .easeOut(duration: 0.15),
                        value: isWiggling
                    )
                    .onDrag {
                        guard isEditing else { return NSItemProvider() }
                        draggedCategory = category
                        return NSItemProvider(object: NSString(string: category))
                    } preview: {
                        chipLabel(for: category, isSelected: isSelected, showsDeleteButton: false)
                    }
                    .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                        guard isEditing else { return }
                        pressedCategory = pressing ? category : nil
                    }, perform: {})
                    .onDrop(
                        of: [UTType.text],
                        delegate: ChipDropDelegate(
                            targetCategory: category,
                            draggedCategory: $draggedCategory,
                            isEditing: isEditing,
                            onMoveCategory: onMoveCategory
                        )
                    )
                    .contextMenu {
                        if !isEditing, let onRequestDelete, isDeletable(category) {
                            Button("Delete", role: .destructive) {
                                onRequestDelete(category)
                            }
                        }
                    }
                }
            }
            .padding(.top, isEditing ? 10 : 2)
            .padding(.bottom, 2)
            .padding(.leading, isEditing ? 2 : 0)
            .onDrop(
                of: [UTType.text],
                delegate: ChipStripDropDelegate(draggedCategory: $draggedCategory)
            )
        }
        .onAppear {
            isWiggling = isEditing
        }
        .onChange(of: isEditing) { _, newValue in
            isWiggling = newValue
            if !newValue {
                draggedCategory = nil
                pressedCategory = nil
            }
        }
    }

    private func wiggleAngle(for index: Int) -> Angle {
        guard isEditing else { return .degrees(0) }
        let baseAngle = index.isMultiple(of: 2) ? -2.2 : 2.2
        return .degrees(isWiggling ? baseAngle : -baseAngle)
    }

    @ViewBuilder
    private func chipLabel(for category: String, isSelected: Bool, showsDeleteButton: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            Text(category)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(isSelected ? AppTheme.accent : AppTheme.chipInactive)
                .clipShape(Capsule())

            if isEditing, showsDeleteButton, isDeletable(category), let onRequestDelete {
                Button {
                    onRequestDelete(category)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.red)
                        .background(Color.white, in: Circle())
                }
                .buttonStyle(.plain)
                .offset(x: -8, y: -8)
                .zIndex(1)
            }
        }
        .contentShape(.dragPreview, Capsule())
    }
}

private struct ChipDropDelegate: DropDelegate {
    let targetCategory: String
    @Binding var draggedCategory: String?
    let isEditing: Bool
    let onMoveCategory: ((String, String) -> Void)?

    func dropEntered(info: DropInfo) {
        guard isEditing,
              let draggedCategory,
              draggedCategory != targetCategory else {
            return
        }

        onMoveCategory?(draggedCategory, targetCategory)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedCategory = nil
        return isEditing
    }

    func dropExited(info: DropInfo) {
        if !info.hasItemsConforming(to: [UTType.text]) {
            draggedCategory = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard isEditing else { return nil }
        return DropProposal(operation: .move)
    }
}

private struct ChipStripDropDelegate: DropDelegate {
    @Binding var draggedCategory: String?

    func performDrop(info: DropInfo) -> Bool {
        draggedCategory = nil
        return true
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var sel = "All"
        var body: some View {
            ChipSelector(
                categories: ["All", "Tops", "Bottoms", "Shoes", "Accessories"],
                selection: $sel,
                isEditing: true,
                isDeletable: { $0 != "All" }
            )
            .padding()
            .background(AppTheme.background)
        }
    }
    return PreviewWrapper()
}
