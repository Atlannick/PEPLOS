//
//  FashionItemMetadataFormMapper.swift
//  PEPLOS
//
//  Maps Add Item form selections into `FashionItemMetadata` for persistence.
//

import Foundation

enum FashionItemMetadataFormMapper {
    static func build(
        itemCategory: FashionItemCategory,
        primaryColor: FashionColor,
        seasons: Set<FashionSeason>,
        occasions: Set<FashionOccasion>,
        styleTags: Set<FashionStyleTag>
    ) -> FashionItemMetadata {
        let formality: FashionFormality = {
            if styleTags.contains(.elegant) { return .smartCasual }
            if styleTags.contains(.smartCasual) { return .smartCasual }
            return .casual
        }()

        let warmth: FashionWarmth = {
            switch itemCategory {
            case .outerwear: return .warmMidweight
            case .shoes, .hat, .accessory, .bag: return .allSeason
            case .top, .bottom, .dress, .layer: return .allSeason
            }
        }()

        return FashionItemMetadata(
            category: itemCategory,
            primaryColor: primaryColor,
            secondaryColor: nil,
            suitableSeasons: seasons,
            suitableOccasions: occasions,
            styleTags: styleTags,
            formality: formality,
            warmth: warmth,
            fit: .regular,
            statementLevel: .none,
            fabrics: []
        )
    }
}
