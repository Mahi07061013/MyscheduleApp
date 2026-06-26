import SwiftUI
import Charts
import SwiftData

enum DisplayMode: String, CaseIterable {
    case count = "達成回数"
    case duration = "取り組んだ時間"
}

enum ChartPeriod: String, CaseIterable {
    case last7Days = "直近7日間"
    case last1Month = "直近1ヶ月"
    case last1Year = "直近1年"
}

struct ReflectView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var sessions: [PomodoroSession]
    @Query var tasks: [Task]
    @Query var journals: [JournalEntry]

    @State private var displayMode: DisplayMode = .count
    @State private var chartPeriod: ChartPeriod = .last7Days
    @State private var selectedDate: Date? = nil
    @State private var journalContent: String = ""

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

    private var completedTasksByDate: [Date: [Task]] {
        let completed = tasks.filter { $0.completedDate != nil }
        return Dictionary(grouping: completed) { task in
            calendar.startOfDay(for: task.completedDate!)
        }
    }

    private var journalsByDate: [Date: JournalEntry] {
        var dict: [Date: JournalEntry] = [:]
        for journal in journals {
            dict[calendar.startOfDay(for: journal.date)] = journal
        }
        return dict
    }

    // Chart aggregation
    private var chartData: [(date: Date, value: Double)] {
        let today = calendar.startOfDay(for: Date())
        var data: [(date: Date, value: Double)] = []

        switch chartPeriod {
        case .last7Days:
            for i in (0..<7).reversed() {
                guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
                let dailySessions = sessionsByDate[date] ?? []
                let value: Double = displayMode == .count
                    ? Double(dailySessions.count)
                    : dailySessions.reduce(0) { $0 + $1.duration / 60.0 }
                data.append((date: date, value: value))
            }
        case .last1Month:
            for i in (0..<30).reversed() {
                guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
                let dailySessions = sessionsByDate[date] ?? []
                let value: Double = displayMode == .count
                    ? Double(dailySessions.count)
                    : dailySessions.reduce(0) { $0 + $1.duration / 60.0 }
                data.append((date: date, value: value))
            }
        case .last1Year:
            for i in (0..<12).reversed() {
                guard let monthDate = calendar.date(byAdding: .month, value: -i, to: today),
                      let startOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start else { continue }

                var monthlyValue: Double = 0
                for session in sessions.filter({ $0.task?.isRest != true }) {
                    if calendar.isDate(session.date, equalTo: startOfMonth, toGranularity: .month) {
                        monthlyValue += displayMode == .count ? 1.0 : session.duration / 60.0
                    }
                }
                data.append((date: startOfMonth, value: monthlyValue))
            }
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
                    Picker("表示モード", selection: $displayMode) {
                        ForEach(DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("カレンダー")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                            ForEach(currentMonthDates.indices, id: \.self) { index in
                                let date = currentMonthDates[index]
                                let isCurrentMonth = calendar.isDate(date, equalTo: Date(), toGranularity: .month)
                                let startOfDay = calendar.startOfDay(for: date)
                                let hasSessions = !(sessionsByDate[startOfDay]?.isEmpty ?? true)
                                let hasCompletedTasks = !(completedTasksByDate[startOfDay]?.isEmpty ?? true)
                                let hasJournal = journalsByDate[startOfDay] != nil
                                let isSelected = selectedDate == startOfDay

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(hasSessions ? Color.green.opacity(0.8) : Color.gray.opacity(0.2))
                                    .frame(height: 40)
                                    .overlay {
                                        ZStack {
                                            Text("\(calendar.component(.day, from: date))")
                                                .font(.caption2)
                                                .foregroundColor(isCurrentMonth ? .primary : .secondary)

                                            if hasCompletedTasks {
                                                VStack {
                                                    HStack {
                                                        Spacer()
                                                        Text("⭐")
                                                            .font(.system(size: 8))
                                                    }
                                                    Spacer()
                                                }
                                                .padding(2)
                                            }

                                            if hasJournal {
                                                VStack {
                                                    HStack {
                                                        Text("💬")
                                                            .font(.system(size: 8))
                                                        Spacer()
                                                    }
                                                    Spacer()
                                                }
                                                .padding(2)
                                            }
                                        }
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                    .onTapGesture {
                                        selectedDate = startOfDay
                                        journalContent = journalsByDate[startOfDay]?.content ?? ""
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if let selectedDate = selectedDate {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(calendar.component(.month, from: selectedDate))月\(calendar.component(.day, from: selectedDate))日の詳細")
                                .font(.headline)

                            let dailySessions = sessionsByDate[selectedDate] ?? []
                            let totalMinutes = dailySessions.reduce(0) { $0 + $1.duration / 60.0 }
                            let hours = Int(totalMinutes) / 60
                            let minutes = Int(totalMinutes) % 60
                            Text("取り組んだ時間: \(hours > 0 ? "\(hours)h " : "")\(minutes)m")
                                .font(.subheadline)

                            let dailyTasks = completedTasksByDate[selectedDate] ?? []
                            if !dailyTasks.isEmpty {
                                Text("達成したタスク:")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                ForEach(dailyTasks) { task in
                                    Text("・ \(task.title)")
                                        .font(.caption)
                                }
                            }

                            Text("コメント")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            TextEditor(text: $journalContent)
                                .frame(height: 80)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))

                            Button("保存") {
                                saveJournal(for: selectedDate)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("実績グラフ")
                                .font(.headline)
                            Spacer()
                            Picker("期間", selection: $chartPeriod) {
                                ForEach(ChartPeriod.allCases, id: \.self) { period in
                                    Text(period.rawValue).tag(period)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal)

                        Chart {
                            ForEach(chartData, id: \.date) { dataPoint in
                                BarMark(
                                    x: .value("日付", dataPoint.date, unit: chartPeriod == .last1Year ? .month : .day),
                                    y: .value(displayMode == .count ? "回数" : "時間 (分)", dataPoint.value)
                                )
                                .foregroundStyle(Color.blue.gradient)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: chartPeriod == .last1Year ? .month : .day)) { value in
                                AxisGridLine()
                                if chartPeriod == .last1Year {
                                    AxisValueLabel(format: .dateTime.month())
                                } else {
                                    AxisValueLabel(format: .dateTime.month().day())
                                }
                            }
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }

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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近達成したタスク")
                            .font(.headline)
                            .padding(.horizontal)

                        let recentTasks = tasks.filter { $0.completedDate != nil }
                                              .sorted { $0.completedDate! > $1.completedDate! }
                                              .prefix(5)

                        if recentTasks.isEmpty {
                            Text("まだ達成したタスクがありません。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            ForEach(recentTasks) { task in
                                let days = daysTaken(for: task)
                                let totalMinutes = task.pomodoroSessions?.reduce(0) { $0 + $1.duration / 60.0 } ?? 0
                                let hours = Int(totalMinutes) / 60
                                let minutes = Int(totalMinutes) % 60
                                let timeString = hours > 0 ? "\(hours)時間\(minutes)分" : "\(minutes)分"

                                Text("🎉 \(task.title) を達成！ \(days)日かかりました。合計で\(timeString)取り組みました")
                                    .font(.subheadline)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("振り返り")
        }
    }

    private func saveJournal(for date: Date) {
        if let existing = journalsByDate[date] {
            existing.content = journalContent
        } else {
            let newJournal = JournalEntry(date: date, content: journalContent)
            modelContext.insert(newJournal)
        }
        try? modelContext.save()
    }

    private func daysTaken(for task: Task) -> Int {
        guard let start = task.startDate, let end = task.completedDate else { return 1 }
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let components = calendar.dateComponents([.day], from: startDay, to: endDay)
        return max(1, (components.day ?? 0) + 1)
    }
}

#Preview {
    ReflectView()
}
