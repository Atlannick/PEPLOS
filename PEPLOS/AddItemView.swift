//
//  AddItemView.swift
//  PEPLOS
//

import PhotosUI
import SwiftUI
import UIKit

private struct StagedPhoto: Identifiable {
    let id = UUID()
    var fullImageFileName: String
    var thumbnailFileName: String
    var originalImageFileName: String?
    /// Which import pipeline produced the files; mirrors persisted `ClothingItem.importProcessingPath`.
    var importProcessingPath: ClothingImportProcessingPath?
    /// Width ÷ height of the stored display image (for masonry layout).
    var photoAspectRatio: CGFloat
}

private struct PhotoPreviewSession: Identifiable {
    let photoId: UUID
    var id: UUID { photoId }
}

/// Pinterest-style columns: each new item is placed in the shortest column.
private struct WaterfallLayout: Layout {
    var columns: Int
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        computeFrames(proposalWidth: proposal.width ?? 0, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeFrames(proposalWidth: bounds.width, subviews: subviews)
        for i in subviews.indices {
            let frame = result.frames[i]
            subviews[i].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func computeFrames(proposalWidth: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        guard columns > 0, proposalWidth > 0, !subviews.isEmpty else {
            return (CGSize(width: proposalWidth, height: 0), [])
        }
        let colWidth = (proposalWidth - CGFloat(columns - 1) * horizontalSpacing) / CGFloat(columns)
        var colBottom = Array(repeating: CGFloat(0), count: columns)
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)

        for subview in subviews {
            let h = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil)).height
            let col = colBottom.enumerated().min(by: { $0.element < $1.element })!.offset
            let x = CGFloat(col) * (colWidth + horizontalSpacing)
            let y = colBottom[col]
            frames.append(CGRect(x: x, y: y, width: colWidth, height: h))
            colBottom[col] = y + h + verticalSpacing
        }

        let maxBottom = colBottom.max() ?? 0
        let totalHeight = max(0, maxBottom - verticalSpacing)
        return (CGSize(width: proposalWidth, height: totalHeight), frames)
    }
}

struct AddItemView: View {
    @EnvironmentObject private var closet: ClosetStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var stagedPhotos: [StagedPhoto] = []
    @State private var photoPreviewSession: PhotoPreviewSession?
    @State private var showCamera = false
    @State private var showAddCategorySheet = false
    @State private var newCategoryDraft = ""
    @State private var addCategoryError: String?
    @FocusState private var newCategoryFieldFocused: Bool
    @State private var isLoadingLibraryPhotos = false

    /// Library multi-select: at least 20 in one picker session (cap keeps memory predictable).
    private let maxLibrarySelectionCount = 50

    private let masonryColumnCount = 3
    /// Space between thumbnails (they must not touch).
    private let masonryItemSpacing: CGFloat = 12
    /// Inset from the dashed border so thumbnails never touch it.
    private let masonryContentPadding: CGFloat = 14

    private var categories: [String] {
        closet.allCategoryNames
    }

    private var canAddItems: Bool {
        selectedCategory != nil && !stagedPhotos.isEmpty
    }

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// Taller drop zone; scales with window height (avoids deprecated `UIScreen.main`).
    private var photoDropZoneHeight: CGFloat {
        #if os(iOS)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let h = scene.screen.bounds.height
            return min(480, max(340, h * 0.46))
        }
        #endif
        return 380
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Category", showSeeAll: false)
                        categoryCard
                    }

                    if selectedCategory != nil {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(title: "Photos", showSeeAll: false)
                            uploadArea
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                addButton
            }
            .onChange(of: selectedCategory) { oldValue, newValue in
                if oldValue != newValue {
                    Self.deleteStagedImageFiles(stagedPhotos)
                    stagedPhotos = []
                    photoPreviewSession = nil
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    await MainActor.run { isLoadingLibraryPhotos = true }
                    defer {
                        Task { @MainActor in
                            isLoadingLibraryPhotos = false
                        }
                    }
                    for item in newItems {
                        guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                        let processed = try? await Task.detached(priority: .userInitiated) {
                            try await ImageProcessor.processImportData(data)
                        }.value
                        if let processed {
                            await MainActor.run {
                                stagedPhotos.append(
                                    StagedPhoto(
                                        fullImageFileName: processed.fullImageFileName,
                                        thumbnailFileName: processed.thumbnailFileName,
                                        originalImageFileName: processed.originalImageFileName,
                                        importProcessingPath: processed.importProcessingPath,
                                        photoAspectRatio: processed.photoAspectRatio
                                    )
                                )
                            }
                        }
                    }
                    await MainActor.run {
                        selectedPhotoItems = []
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { processed in
                    if let processed {
                        stagedPhotos.append(
                            StagedPhoto(
                                fullImageFileName: processed.fullImageFileName,
                                thumbnailFileName: processed.thumbnailFileName,
                                originalImageFileName: processed.originalImageFileName,
                                importProcessingPath: processed.importProcessingPath,
                                photoAspectRatio: processed.photoAspectRatio
                            )
                        )
                    }
                }
            }
            .sheet(isPresented: $showAddCategorySheet) {
                addCategoryNameSheet
            }
            .onChange(of: showAddCategorySheet) { _, isPresented in
                if !isPresented {
                    newCategoryDraft = ""
                    addCategoryError = nil
                    newCategoryFieldFocused = false
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.45, green: 0.46, blue: 0.48))
                            .frame(width: 32, height: 32)
                            .background(Color(red: 0.95, green: 0.95, blue: 0.96))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .fullScreenCover(item: $photoPreviewSession) { session in
                if let photo = stagedPhotos.first(where: { $0.id == session.photoId }) {
                    BatchPhotoFullscreenView(
                        fullImageFileName: photo.fullImageFileName,
                        onRemove: {
                            ClothingImageStorage.deleteImages(
                                fullImageFileName: photo.fullImageFileName,
                                thumbnailFileName: photo.thumbnailFileName,
                                originalImageFileName: photo.originalImageFileName
                            )
                            stagedPhotos.removeAll { $0.id == session.photoId }
                            photoPreviewSession = nil
                        },
                        onClose: { photoPreviewSession = nil }
                    )
                }
            }
            .overlay {
                if isLoadingLibraryPhotos {
                    libraryPhotosLoadingOverlay
                }
            }
            .animation(.easeInOut(duration: 0.22), value: isLoadingLibraryPhotos)
            .onDisappear {
                Self.deleteStagedImageFiles(stagedPhotos)
            }
        }
    }

    private static func deleteStagedImageFiles(_ photos: [StagedPhoto]) {
        for p in photos {
            ClothingImageStorage.deleteImages(
                fullImageFileName: p.fullImageFileName,
                thumbnailFileName: p.thumbnailFileName,
                originalImageFileName: p.originalImageFileName
            )
        }
    }

    private var libraryPhotosLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppTheme.accent)
                Text("Loading photos…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.subtitleGray)
                Text("Importing from your library")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtitleGray.opacity(0.9))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .pepCardShadow()
            .padding(.horizontal, 36)
        }
        .allowsHitTesting(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading photos from library")
    }

    private var uploadArea: some View {
        VStack(spacing: 18) {
            previewArea

            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: maxLibrarySelectionCount,
                    selectionBehavior: .ordered,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    sourceButton(
                        title: stagedPhotos.isEmpty ? "Add from Library" : "Add more from Library",
                        systemImage: "photo.on.rectangle"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    presentCamera()
                } label: {
                    sourceButton(
                        title: stagedPhotos.isEmpty ? "Take Photo" : "Take Another",
                        systemImage: "camera.fill"
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isCameraAvailable)
                .opacity(isCameraAvailable ? 1 : 0.45)
            }

            if !stagedPhotos.isEmpty {
                Text(
                    "Up to \(maxLibrarySelectionCount) photos per library pick. Tap thumbnails to preview or remove."
                )
                .font(.caption)
                .foregroundStyle(AppTheme.subtitleGray)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .pepCardShadow()
    }

    private var previewArea: some View {
        let dashedAreaHeight: CGFloat = stagedPhotos.isEmpty ? photoDropZoneHeight : min(photoDropZoneHeight, 340)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.background)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            AppTheme.searchButtonBorder,
                            style: StrokeStyle(lineWidth: 2, dash: [10, 7])
                        )
                }
                .frame(height: dashedAreaHeight)

            if stagedPhotos.isEmpty {
                VStack(spacing: 16) {
                    Button {
                        presentCamera()
                    } label: {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppTheme.cardBackground)
                            .frame(width: 76, height: 76)
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(AppTheme.searchButtonBorder, lineWidth: 1)
                            }
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .pepSubtleShadow()
                    }
                    .buttonStyle(.plain)
                    .disabled(!isCameraAvailable)
                    .opacity(isCameraAvailable ? 1 : 0.45)
                    .accessibilityLabel("Take photo")

                    Text("Add one or many photos for \(selectedCategory ?? "").")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtitleGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    HStack(spacing: 8) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.subtitleGray.opacity(0.85))
                        Text("Please use a solid background to get better results.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtitleGray.opacity(0.85))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(stagedPhotos.count)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.leading, masonryContentPadding)
                        .padding(.top, masonryContentPadding)
                        .accessibilityLabel("\(stagedPhotos.count) photos staged")

                    ScrollView(.vertical, showsIndicators: false) {
                        WaterfallLayout(
                            columns: masonryColumnCount,
                            horizontalSpacing: masonryItemSpacing,
                            verticalSpacing: masonryItemSpacing
                        ) {
                            ForEach(stagedPhotos) { photo in
                                stagedThumbnailCell(photo: photo)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, masonryContentPadding)
                        .padding(.top, 10)
                        .padding(.bottom, masonryContentPadding)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(height: dashedAreaHeight)
    }

    private func stagedThumbnailCell(photo: StagedPhoto) -> some View {
        let thumbURL = ClothingImageStorage.fileURL(fileName: photo.thumbnailFileName)
        return ZStack(alignment: .topTrailing) {
            Button {
                photoPreviewSession = PhotoPreviewSession(photoId: photo.id)
            } label: {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipped()
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 80)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(AppTheme.subtitleGray)
                            .frame(maxWidth: .infinity, minHeight: 80)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                ClothingImageStorage.deleteImages(
                    fullImageFileName: photo.fullImageFileName,
                    thumbnailFileName: photo.thumbnailFileName,
                    originalImageFileName: photo.originalImageFileName
                )
                stagedPhotos.removeAll { $0.id == photo.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white, .black.opacity(0.45))
            }
            .buttonStyle(.plain)
            .padding(3)
            .accessibilityLabel("Remove photo")
        }
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick a category first, then add as many photos as you want for that shelf.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtitleGray)

            categoryChips

            addCategoryRowButton
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .pepCardShadow()
    }

    private var addCategoryRowButton: some View {
        Button {
            newCategoryDraft = ""
            addCategoryError = nil
            showAddCategorySheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                Text("Add Category")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(AppTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppTheme.accent.opacity(0.32), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Creates a new shelf for organizing items")
    }

    private var addCategoryNameSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Category name", text: $newCategoryDraft)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($newCategoryFieldFocused)
                    .onSubmit { submitNewCategory() }
                    .padding(14)
                    .background(AppTheme.chipInactive)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let addCategoryError {
                    Text(addCategoryError)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.background)
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddCategorySheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        submitNewCategory()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                newCategoryFieldFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func submitNewCategory() {
        let trimmed = newCategoryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            addCategoryError = "Enter a category name."
            return
        }
        if let added = closet.addCategory(trimmed) {
            selectedCategory = added
            showAddCategorySheet = false
        } else {
            addCategoryError = "A category with this name already exists."
        }
    }

    private func presentCamera() {
        guard isCameraAvailable else { return }
        showCamera = true
    }

    private func sourceButton(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(AppTheme.accent)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 54)
        .padding(.horizontal, 12)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// Two flexible columns so every label fits on-screen without horizontal scrolling (wraps vertically instead).
    private let categoryGridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    private var categoryChips: some View {
        LazyVGrid(columns: categoryGridColumns, alignment: .center, spacing: 10) {
            ForEach(categories, id: \.self) { cat in
                categoryChipButton(cat)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func categoryChipButton(_ cat: String) -> some View {
        let selected = selectedCategory == cat
        return Button {
            selectedCategory = cat
        } label: {
            Text(cat)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(selected ? AppTheme.accent : AppTheme.chipInactive)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button {
            guard let shelf = selectedCategory else { return }
            closet.addItems(
                categoryName: shelf,
                imageReferences: stagedPhotos.map {
                    (
                        fullImageFileName: $0.fullImageFileName,
                        thumbnailFileName: $0.thumbnailFileName,
                        photoAspectRatio: $0.photoAspectRatio,
                        originalImageFileName: $0.originalImageFileName,
                        importProcessingPath: $0.importProcessingPath
                    )
                },
                fashionMetadata: nil
            )
            stagedPhotos = []
            dismiss()
        } label: {
            let count = stagedPhotos.count
            Text(count > 1 ? "Add \(count) photos" : "Add photo")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.62, blue: 1.0),
                            AppTheme.accent,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(canAddItems ? 1 : 0.45)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canAddItems)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.background.opacity(0.98))
        .onAppear {
            if let selectedCategory, !categories.contains(selectedCategory) {
                self.selectedCategory = nil
            }
        }
    }

}

// MARK: - Fullscreen preview (batch)

private struct BatchPhotoFullscreenView: View {
    let fullImageFileName: String
    let onRemove: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AsyncImage(url: ClothingImageStorage.fileURL(fileName: fullImageFileName)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .empty:
                    ProgressView()
                        .tint(.white)
                case .failure:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.5))
                @unknown default:
                    EmptyView()
                }
            }
        }
        .overlay(alignment: .top) {
            HStack {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white, .white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")

                Spacer()

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove photo")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Camera (appends each capture)

private struct CameraImagePicker: UIViewControllerRepresentable {
    var onCapture: (ProcessedClothingImport?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCapture(nil)
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onCapture(nil)
                parent.dismiss()
                return
            }
            Task {
                let result = try? await Task.detached(priority: .userInitiated) {
                    try await ImageProcessor.processImportUIImage(image)
                }.value
                await MainActor.run {
                    self.parent.onCapture(result)
                    self.parent.dismiss()
                }
            }
        }
    }
}

#Preview {
    AddItemView()
        .environmentObject(ClosetStore())
}
