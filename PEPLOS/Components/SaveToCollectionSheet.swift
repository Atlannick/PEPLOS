//
//  SaveToCollectionSheet.swift
//  PEPLOS
//

import SwiftUI

struct SaveToCollectionSheet: View {
    @EnvironmentObject private var collectionService: CollectionService
    @Environment(\.dismiss) private var dismiss

    let outfitId: UUID
    let onSaved: () -> Void

    @State private var showCreateCollection = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        showCreateCollection = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                            Text("New Collection")
                                .font(.body.weight(.semibold))
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.subtitleGray)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    Divider()
                        .padding(.vertical, 8)

                    if collectionService.collections.isEmpty {
                        Text("No collections yet — create one above.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtitleGray)
                            .padding(.top, 8)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(collectionService.collections) { collection in
                                Button {
                                    select(collection)
                                } label: {
                                    HStack {
                                        Text(collection.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.subtitleGray)
                                    }
                                    .padding(.vertical, 14)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if collection.id != collectionService.collections.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Save to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showCreateCollection) {
            CreateCollectionModal { name in
                guard let created = collectionService.addCollection(named: name) else { return }
                collectionService.saveOutfit(outfitId, toCollectionId: created.id)
                DispatchQueue.main.async {
                    dismiss()
                    onSaved()
                }
            }
        }
    }

    private func select(_ collection: CollectionModel) {
        collectionService.saveOutfit(outfitId, toCollectionId: collection.id)
        dismiss()
        onSaved()
    }
}

#Preview {
    SaveToCollectionSheet(outfitId: UUID(), onSaved: {})
        .environmentObject(CollectionService())
}
