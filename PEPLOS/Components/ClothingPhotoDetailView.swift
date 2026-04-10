//
//  ClothingPhotoDetailView.swift
//  PEPLOS
//

import SwiftUI

struct ClothingPhotoDetailView: View {
    let item: ClosetItem
    @EnvironmentObject private var closet: ClosetStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showMetadataEditor = false

    private var previewThumbNames: [String] {
        if let t = item.thumbnailFileName {
            return [t]
        }
        if let f = item.fullImageFileName {
            return [f]
        }
        return []
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let name = item.fullImageFileName ?? item.thumbnailFileName {
                AsyncImage(url: ClothingImageStorage.fileURL(fileName: name)) { phase in
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
        }
        .overlay(alignment: .top) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white, .white.opacity(0.35))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")

                Spacer()

                if item.hasPhoto {
                    Button {
                        showMetadataEditor = true
                    } label: {
                        Image(systemName: "tag")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Styling details")
                }

                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete item")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .alert("Delete this item?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                closet.removeItem(id: item.id)
                dismiss()
            }
        } message: {
            Text("This photo will be removed from your closet.")
        }
        .sheet(isPresented: $showMetadataEditor) {
            AddItemMetadataView(
                closetShelfName: item.category,
                previewThumbnailFileNames: previewThumbNames,
                existingMetadata: closet.items.first(where: { $0.id == item.id })?.fashionMetadata,
                onCancel: { showMetadataEditor = false },
                onSave: { metadata in
                    closet.updateFashionMetadata(forItemId: item.id, metadata: metadata)
                    showMetadataEditor = false
                },
                onClear: {
                    closet.updateFashionMetadata(forItemId: item.id, metadata: nil)
                    showMetadataEditor = false
                },
                isFromCloset: true
            )
        }
    }
}
