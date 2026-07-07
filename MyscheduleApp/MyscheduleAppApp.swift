//
//  MyscheduleAppApp.swift
//  MyscheduleApp
//
//  Created by Kato Mahiro on 2026/06/15.
//

import SwiftUI
import SwiftData

@main
struct MyscheduleAppApp: App {
    @State private var timerManager = TimerManager()
    @Environment(\.scenePhase) private var scenePhase

    let sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([TaskCategory.self, Task.self, PomodoroSession.self, Tag.self])

        let modelConfiguration: ModelConfiguration
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.myscheduleapp") != nil {
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier("group.com.myscheduleapp"))
        } else {
            // Fallback for when AppGroup entitlement is not yet configured in Xcode
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }

        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(timerManager)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                timerManager.handleScenePhaseBackground()
            } else if newPhase == .active {
                timerManager.handleScenePhaseActive()
            }
        }
    }
}
