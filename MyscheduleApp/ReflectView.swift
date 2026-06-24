import SwiftUI
import Charts
import SwiftData

enum DisplayMode: String, CaseIterable {
    case count = "達成回数"
    case duration = "取り組んだ時間"
}

struct ReflectView: View {
    @Query var sessions: [PomodoroSession]
    @State private var displayMode: DisplayMode = .count

    // MARK: - Helpers

    private var calendar: Calendar {
        Calendar.current
    }

    private var sessionsByDate: [Date: [PomodoroSession]] {
        Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.date)
        }
    }

    // Last 7 days aggregation
    private var last7DaysData: [(date: Date, value: Double)] {
        let today = calendar.startOfDay(for: Date())
        var data: [(date: Date, value: Double)] = []
        for i in (0..<7).reversed() {
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

        for session in sessions {
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("直近7日間の実績")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart {
                            ForEach(last7DaysData, id: \.date) { dataPoint in
                                BarMark(
                                    x: .value("日付", dataPoint.date, unit: .day),
                                    y: .value(displayMode == .count ? "回数" : "時間 (分)", dataPoint.value)
                                )
                                .foregroundStyle(Color.blue.gradient)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { value in
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
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("振り返り")
        }
    }
}

#Preview {
    ReflectView()
}
