//
//  openFitnessApp.swift
//  openFitness
//
//  Created by Aninda Ghosh on 6/5/26.
//

import SwiftUI
import SwiftData

@main
struct openFitnessApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(LocalPersistenceManager.shared.container)
        }
    }
}
