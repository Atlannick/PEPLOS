//
//  PEPLOSApp.swift
//  PEPLOS
//
//  Created by Atlan Nick on 3.04.2026.
//

import SwiftUI

@main
struct PEPLOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Temporary global lock until full Dark Mode design is implemented.
                .preferredColorScheme(.light)
        }
    }
}
