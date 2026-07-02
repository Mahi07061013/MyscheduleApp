import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), lastCompletedDate: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        Swift.Task { @MainActor in
            completion(SimpleEntry(date: Date(), lastCompletedDate: fetchLastCompletedDate()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Swift.Task { @MainActor in
            let lastDate = fetchLastCompletedDate()
            let entry = SimpleEntry(date: Date(), lastCompletedDate: lastDate)

            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 5))) // update every 5 minutes
            completion(timeline)
        }
    }

    @MainActor
    private func fetchLastCompletedDate() -> Date? {
        do {
            let schema = Schema([TaskCategory.self, Task.self, PomodoroSession.self, Tag.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier("group.com.myscheduleapp"))
            let container = try ModelContainer(for: schema, configurations: config)
            let context = container.mainContext
            let descriptor = FetchDescriptor<Task>(sortBy: [SortDescriptor(\.completedDate, order: .reverse)])
            let allTasks = try context.fetch(descriptor)

            if let lastDone = allTasks.first(where: { $0.status == .done }) {
                return lastDone.completedDate
            }
        } catch {
            print("Widget fetch failed: \(error)")
        }
        return nil
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let lastCompletedDate: Date?
}

struct MyscheduleAppWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最後のタスク達成から")
                .font(.caption)
                .foregroundColor(.secondary)

            if let date = entry.lastCompletedDate {
                Text(date, style: .relative)
                    .font(.title2)
                    .bold()
            } else {
                Text("データなし")
                    .font(.title2)
                    .bold()
            }
        }
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

struct MyscheduleAppWidget: Widget {
    let kind: String = "MyscheduleAppWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MyscheduleAppWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("タスク実績ウィジェット")
        .description("最後にタスクを達成してからの経過時間を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
