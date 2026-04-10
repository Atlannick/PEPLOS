//
//  CollectionsBrowserSheet.swift
//  PEPLOS
//

import SwiftUI

/// Browse all collections, create new ones, and open a collection to see its outfits.
struct CollectionsBrowserSheet: View {
    @EnvironmentObject private var collectionService: CollectionService
    @Environment(\.dismiss) private var dismiss

    @State private var showCreateCollection = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showCreateCollection = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                            Text("New Collection")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.subtitleGray)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }

                Section {
                    if collectionService.collections.isEmpty {
                        Text("No collections yet — create one above.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtitleGray)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(collectionService.collections) { collection in
                            NavigationLink {
                                CollectionOutfitsView(collection: collection)
                            } label: {
                                Text(collection.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                            .listRowBackground(AppTheme.cardBackground)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showCreateCollection) {
            CreateCollectionModal { name in
                _ = collectionService.addCollection(named: name)
            }
        }
    }
}

#Preview {
    CollectionsBrowserSheet()
        .environmentObject(CollectionService())
        .environmentObject(OutfitStore())
        .environmentObject(ClosetStore())
}
