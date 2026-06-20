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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [TaskCategory.self, Task.self, WorkSession.self])
    }
}
