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
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier("group.com.myscheduleapp"))

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
