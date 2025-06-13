//
//  OptimusApp.swift
//  Optimus
//
//  Created by Pritam Panda on 6/6/25.
//

// MolecularStructureApp.swift


import SwiftUI
import SwiftData
import WebKit
import UniformTypeIdentifiers

// MARK: - App Entry Point
@main
struct OptimusDrugDesignApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Molecule.self,
            SearchHistory.self,
            DesignProject.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainDashboardView()
        }
        .modelContainer(sharedModelContainer)
    }
}
