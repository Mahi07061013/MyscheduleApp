import SwiftUI
import Charts
import SwiftData

enum DisplayMode: String, CaseIterable {
    case count = "取り組んだ回数"
    case duration = "取り組んだ時間"
}

struct ReflectView: View {
    @Query var sessions: [PomodoroSession]
    @Query var allTasks: [Task]
    @State private var displayMode: DisplayMode = .count
    @State private var showingRankingSheet = false

    // MARK: - Helpers

    private var calendar: Calendar {
        Calendar.current
    }

    private var filteredSessions: [PomodoroSession] {
        sessions.filter { $0.task?.isRest == false }
    }

    private var sessionsByDate: [Date: [PomodoroSession]] {
        Dictionary(grouping: filteredSessions) { session in
            calendar.startOfDay(for: session.date)
        }
    }

    // Last 7 days aggregation
    private var last30DaysData: [(date: Date, value: Double)] {
        let today = calendar.startOfDay(for: Date())
        var data: [(date: Date, value: Double)] = []
        for i in (0..<30).reversed() {
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
        let averageMood: Double?
    }

    private var categoryData: [CategoryData] {
        var grouped: [String: (colorHex: String?, value: Double, moods: [Int])] = [:]

        for session in filteredSessions {
            let categoryName = session.task?.category?.name ?? "未分類"
            let colorHex = session.task?.category?.themeColorHex

            let amount: Double = displayMode == .count
                ? 1.0
                : session.duration / 60.0 // minutes

            if var existing = grouped[categoryName] {
                existing.colorHex = existing.colorHex ?? colorHex
                existing.value += amount
                if let mood = session.moodRating { existing.moods.append(mood) }
                grouped[categoryName] = existing
            } else {
                var moods: [Int] = []
                if let mood = session.moodRating { moods.append(mood) }
                grouped[categoryName] = (colorHex: colorHex, value: amount, moods: moods)
            }
        }

        return grouped.map { key, data in
            let avgMood = data.moods.isEmpty ? nil : Double(data.moods.reduce(0, +)) / Double(data.moods.count)
            return CategoryData(name: key, colorHex: data.colorHex, value: data.value, averageMood: avgMood)
        }.sorted { $0.value > $1.value }
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("カレンダー")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                            ForEach(currentMonthDates, id: \.self) { date in
                                let isCurrentMonth = calendar.isDate(date, equalTo: Date(), toGranularity: .month)
                                let hasSessions = !(sessionsByDate[date]?.isEmpty ?? true)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(hasSessions ? Color.green.opacity(0.8) : Color.gray.opacity(0.2))
                                    .frame(height: 40)
                                    .overlay {
                                        Text("\(calendar.component(.day, from: date))")
                                            .font(.caption2)
                                            .foregroundColor(isCurrentMonth ? .primary : .secondary)
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Picker("表示モード", selection: $displayMode) {
                        ForEach(DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)



                    VStack(alignment: .leading, spacing: 8) {
                        Text("直近30日間の実績")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart {
                            ForEach(last30DaysData, id: \.date) { dataPoint in
                                BarMark(
                                    x: .value("日付", dataPoint.date, unit: .day),
                                    y: .value(displayMode == .count ? "回数" : "時間 (分)", dataPoint.value)
                                )
                                .foregroundStyle(Color.blue.gradient)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: 10)) { value in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month().day())
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

                        // Ranking List
                        VStack(spacing: 8) {
                            ForEach(Array(categoryData.prefix(5).enumerated()), id: \.element.id) { index, data in
                                HStack {
                                    Text("\(index + 1)位")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .leading)
                                    Circle()
                                        .fill(data.colorHex != nil ? Color(hex: data.colorHex!)! : Color.blue)
                                        .frame(width: 10, height: 10)
                                    Text(data.name)
                                        .font(.subheadline)
                                    Spacer()
                                    if let mood = data.averageMood {
                                        Text(String(format: "気分: %.1f", mood))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    let valText = displayMode == .count ? "\(Int(data.value))回" : "\(Int(data.value))m"
                                    Text(valText)
                                        .font(.subheadline)
                                        .bold()
                                }
                                .padding(.vertical, 4)
                            }

                            if categoryData.count > 5 {
                                Button("詳細を表示") {
                                    showingRankingSheet = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // Recent Tasks
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近達成したタスク一覧")
                            .font(.headline)
                            .padding(.horizontal)

                        let recentTasks = allTasks.filter { $0.status == .done && $0.isRest == false }.sorted { ($0.completedDate ?? Date.distantPast) > ($1.completedDate ?? Date.distantPast) }.prefix(10)

                        if recentTasks.isEmpty {
                            Text("まだ達成したタスクはありません")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            ForEach(Array(recentTasks)) { task in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading) {
                                        Text(task.title)
                                            .font(.subheadline)
                                        if let date = task.completedDate {
                                            Text(date.formatted())
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("振り返り")
        }
        .sheet(isPresented: $showingRankingSheet) {
            NavigationStack {
                List {
                    ForEach(Array(categoryData.enumerated()), id: \.element.id) { index, data in
                        HStack {
                            Text("\(index + 1)位")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)
                            Circle()
                                .fill(data.colorHex != nil ? Color(hex: data.colorHex!)! : Color.blue)
                                .frame(width: 10, height: 10)
                            Text(data.name)
                                .font(.subheadline)
                            Spacer()
                            if let mood = data.averageMood {
                                Text(String(format: "気分: %.1f", mood))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            let valText = displayMode == .count ? "\(Int(data.value))回" : "\(Int(data.value))m"
                            Text(valText)
                                .font(.subheadline)
                                .bold()
                        }
                    }
                }
                .navigationTitle("ランキング詳細")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    ReflectView()
}
