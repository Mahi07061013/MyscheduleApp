import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), latestCompletedDate: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        Task {
            let date = await getLatestCompletedTaskDate()
            let entry = SimpleEntry(date: Date(), latestCompletedDate: date)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        Task {
            let date = await getLatestCompletedTaskDate()
            let entries = [SimpleEntry(date: Date(), latestCompletedDate: date)]
            // Since we are showing a relative date which updates continuously in the view,
            // we only need to reload the timeline when the app changes the data.
            let timeline = Timeline(entries: entries, policy: .never)
            completion(timeline)
        }
    }

    @MainActor
    private func getLatestCompletedTaskDate() -> Date? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.myscheduleapp") else {
            return nil
        }

        let schema = Schema([TaskCategory.self, Task.self, PomodoroSession.self, Tag.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier("group.com.myscheduleapp"))

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let descriptor = FetchDescriptor<Task>()
            let allTasks = try container.mainContext.fetch(descriptor)

            let completedTasks = allTasks.filter { $0.status == .done }.compactMap { $0.completedDate }
            return completedTasks.max()
        } catch {
            return nil
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let latestCompletedDate: Date?
}

struct MyscheduleAppWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            if let completedDate = entry.latestCompletedDate {
                Text("最近のタスクが終わってから:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text(completedDate, style: .relative)
                    .font(.title2)
                    .bold()
            } else {
                Text("まだ完了したタスクはありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

struct MyscheduleAppWidget: Widget {
    let kind: String = "MyscheduleAppWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MyscheduleAppWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Myschedule")
        .description("最近の完了済みタスクからの経過時間を表示します。")
    }
}
