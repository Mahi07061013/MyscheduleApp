import SwiftUI
import Charts
import SwiftData

enum DisplayMode: String, CaseIterable {
    case count = "達成回数"
    case duration = "取り組んだ時間"
}

enum ChartPeriod: String, CaseIterable {
    case week = "直近7日間"
    case month = "直近1ヶ月"
    case year = "直近1年"
}

struct ReflectView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var sessions: [PomodoroSession]
    @Query(sort: \Task.completedDate, order: .reverse) var allTasks: [Task]
    @Query var journalEntries: [JournalEntry]

    @State private var displayMode: DisplayMode = .count
    @State private var chartPeriod: ChartPeriod = .week
    @State private var selectedDate: Date = Date()
    @State private var journalText: String = ""

    // MARK: - Helpers

    private var calendar: Calendar {
        Calendar.current
    }

    private var filteredSessions: [PomodoroSession] {
        sessions.filter { $0.task?.isRest != true }
    }

    private var sessionsByDate: [Date: [PomodoroSession]] {
        Dictionary(grouping: filteredSessions) { session in
            calendar.startOfDay(for: session.date)
        }
    }

    // Chart data aggregation
    private var chartData: [(date: Date, value: Double)] {
        let today = calendar.startOfDay(for: Date())
        var data: [(date: Date, value: Double)] = []

        let daysToFetch: Int
        switch chartPeriod {
        case .week: daysToFetch = 7
        case .month: daysToFetch = 30
        case .year: daysToFetch = 365
        }

        for i in (0..<daysToFetch).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let dailySessions = sessionsByDate[date] ?? []
            let value: Double = displayMode == .count
                ? Double(dailySessions.count)
                : dailySessions.reduce(0) { $0 + $1.duration / 60.0 } // minutes
            data.append((date: date, value: value))
        }
        return data
    }

    // Category aggregation
    private struct CategoryData: Identifiable {
        let id = UUID()
        let name: String
        let colorHex: String?
        let value: Double
    }

    private var categoryData: [CategoryData] {
        var grouped: [String: (colorHex: String?, value: Double)] = [:]

        for session in filteredSessions {
            let categoryName = session.task?.category?.name ?? "未分類"
            let colorHex = session.task?.category?.themeColorHex

            let amount: Double = displayMode == .count
                ? 1.0
                : session.duration / 60.0 // minutes

            if let existing = grouped[categoryName] {
                grouped[categoryName] = (colorHex: existing.colorHex ?? colorHex, value: existing.value + amount)
            } else {
                grouped[categoryName] = (colorHex: colorHex, value: amount)
            }
        }

        return grouped.map { CategoryData(name: $0.key, colorHex: $0.value.colorHex, value: $0.value.value) }
            .sorted { $0.value > $1.value }
    }

    private var totalCategoryValue: Double {
        categoryData.reduce(0) { $0 + $1.value }
    }

    // Calendar grid calculation
    private var currentMonthDates: [Date] {
        let today = Date()
        guard let monthInterval = calendar.dateInterval(of: .month, for: today) else { return [] }

        var dates: [Date] = []
        var currentDate = monthInterval.start

        // Add dates before the start of the month to align with weekday
        let weekday = calendar.component(.weekday, from: currentDate)
        let offset = (weekday - calendar.firstWeekday + 7) % 7

        if let startDate = calendar.date(byAdding: .day, value: -offset, to: currentDate) {
            currentDate = startDate
        }

        // 6 weeks (42 days) to ensure we cover the whole month
        for _ in 0..<42 {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        return dates
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    calendarSection
                    controlsSection
                    journalSection
                    chartSection
                    categorySection
                    motivationSection
                }
                .padding(.vertical)
            }
            .navigationTitle("振り返り")
        }
    }

    // MARK: - View Sections

    @ViewBuilder
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カレンダー")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(currentMonthDates, id: \.self) { date in
                    let isCurrentMonth = calendar.isDate(date, equalTo: Date(), toGranularity: .month)
                    let isSelectedDate = calendar.isDate(date, equalTo: selectedDate, toGranularity: .day)
                    let hasSessions = !(sessionsByDate[date]?.isEmpty ?? true)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(hasSessions ? Color.green.opacity(0.8) : Color.gray.opacity(0.2))
                        .frame(height: 40)
                        .overlay {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.caption2)
                                .foregroundColor(isCurrentMonth ? .primary : .secondary)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelectedDate ? Color.blue : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedDate = date
                            loadJournalEntry(for: date)
                        }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var controlsSection: some View {
        HStack {
            Picker("表示モード", selection: $displayMode) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("期間", selection: $chartPeriod) {
                ForEach(ChartPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(selectedDate, format: .dateTime.month().day()) の日記")
                .font(.headline)
                .padding(.horizontal)

            TextEditor(text: $journalText)
                .frame(minHeight: 100)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal)

            Button(action: saveJournalEntry) {
                Text("保存")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .onAppear {
            loadJournalEntry(for: selectedDate)
        }
    }

    // MARK: - Journal Actions

    private func loadJournalEntry(for date: Date) {
        if let entry = journalEntries.first(where: { calendar.isDate($0.date, equalTo: date, toGranularity: .day) }) {
            journalText = entry.content
        } else {
            journalText = ""
        }
    }

    private func saveJournalEntry() {
        if let entry = journalEntries.first(where: { calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .day) }) {
            entry.content = journalText
        } else {
            let newEntry = JournalEntry(date: selectedDate, content: journalText)
            modelContext.insert(newEntry)
        }
        try? modelContext.save()
    }

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(chartPeriod.rawValue)の実績")
                .font(.headline)
                .padding(.horizontal)

            Chart {
                ForEach(chartData, id: \.date) { dataPoint in
                    BarMark(
                        x: .value("日付", dataPoint.date, unit: .day),
                        y: .value(displayMode == .count ? "回数" : "時間 (分)", dataPoint.value)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
            }
            .chartXAxis {
                let strideUnit: Calendar.Component = chartPeriod == .year ? .month : .day
                let format: Date.FormatStyle = chartPeriod == .year ? .dateTime.year().month() : .dateTime.month().day()

                AxisMarks(values: .stride(by: strideUnit)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: format)
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("カテゴリ別の実績")
                .font(.headline)
                .padding(.horizontal)

            ZStack {
                Chart {
                    ForEach(categoryData) { dataPoint in
                        SectorMark(
                            angle: .value(displayMode == .count ? "回数" : "時間", dataPoint.value),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("カテゴリ", dataPoint.name))
                        .cornerRadius(4)
                    }
                }
                .frame(height: 250)
                .padding(.horizontal)

                VStack {
                    Text("合計")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if displayMode == .count {
                        Text("\(Int(totalCategoryValue)) 回")
                            .font(.title2)
                            .bold()
                    } else {
                        let hours = Int(totalCategoryValue) / 60
                        let minutes = Int(totalCategoryValue) % 60
                        if hours > 0 {
                            Text("\(hours)h \(minutes)m")
                                .font(.title2)
                                .bold()
                        } else {
                            Text("\(minutes)m")
                                .font(.title2)
                                .bold()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var motivationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近達成したタスク")
                .font(.headline)
                .padding(.horizontal)

            let completedTasks = allTasks.filter { $0.status == .done }
                .sorted { ($0.completedDate ?? Date.distantPast) > ($1.completedDate ?? Date.distantPast) }
                .prefix(5)

            if completedTasks.isEmpty {
                Text("まだ達成したタスクはありません。")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(completedTasks) { task in
                    let daysTaken = calculateDaysTaken(for: task)
                    let totalTime = calculateTotalTime(for: task)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("🎉 [\(task.title)] を達成！ \(daysTaken)日かかりました。合計で\(totalTime)時間取り組みました")
                            .font(.subheadline)
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Motivation Helpers

    private func calculateDaysTaken(for task: Task) -> Int {
        guard let start = task.startDate, let end = task.completedDate else { return 0 }
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end))
        return max(1, (components.day ?? 0) + 1) // If done on the same day, it counts as 1 day
    }

    private func calculateTotalTime(for task: Task) -> Double {
        let sessions = task.pomodoroSessions ?? []
        let totalSeconds = sessions.reduce(0) { $0 + $1.duration }
        let hours = totalSeconds / 3600.0
        // Round to 1 decimal place
        return (hours * 10).rounded() / 10
    }
}

#Preview {
    ReflectView()
}
