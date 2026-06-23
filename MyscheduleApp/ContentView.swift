import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            FocusView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }

            ReflectView()
                .tabItem {
                    Label("Reflect", systemImage: "chart.bar")
                }

            TaskManagementView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TaskCategory.self, Task.self, WorkSession.self], inMemory: true)
}
