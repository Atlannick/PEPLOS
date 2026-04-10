//
//  MainTab.swift
//  PEPLOS
//

import SwiftUI

enum MainTab: Int, CaseIterable, Hashable {
    case home
    case closet
    case stylist
    case outfits
    case settings

    var title: String {
        switch self {
        case .home: "HOME"
        case .closet: "CLOSET"
        case .stylist: "STYLIST"
        case .outfits: "OUTFITS"
        case .settings: "SET"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "square.grid.2x2"
        case .closet: "tshirt"
        case .stylist: "sparkles"
        case .outfits: "heart"
        case .settings: "gearshape"
        }
    }
}
