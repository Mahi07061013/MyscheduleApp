import SwiftUI
import SwiftData
import Charts

// Color Extension for Hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

enum DisplayMode: String, CaseIterable {
    case count = "達成回数"
    case time = "取り組んだ時間"
}

struct DailyStat: Identifiable {
    var id: Date { date }
    var date: Date
    var count: Int
    var duration: TimeInterval
}

struct CategoryStat: Identifiable {
    var id: String { name }
    var name: String
    var count: Int
    var duration: TimeInterval
    var colorHex: String?
}

struct ReflectView: View {
    @Query private var sessions: [PomodoroSession]
    @State private var displayMode: DisplayMode = .count

    // Date ranges
    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    // Grouped Sessions
    private var groupedSessionsByDay: [Date: [PomodoroSession]] {
        Dictionary(grouping: sessions) { session in
            Calendar.current.startOfDay(for: session.date)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Display Mode Picker
                Picker("表示モード", selection: $displayMode) {
                    ForEach(DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Calendar View
                calendarSection

                // Bar Chart
                barChartSection

                // Donut Chart
                donutChartSection
            }
            .padding(.vertical)
        }
        .navigationTitle("振り返り")
    }

    // MARK: - Calendar
    private var calendarSection: some View {
        VStack(alignment: .leading) {
            Text("今月の記録")
                .font(.headline)
                .padding(.horizontal)

            let days = daysInCurrentMonth()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Day of week headers
                ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        let stat = statForDate(date)
                        let intensity = colorIntensity(for: stat)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(intensity > 0 ? Color.green.opacity(intensity) : Color.gray.opacity(0.2))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.caption2)
                                    .foregroundColor(intensity > 0.5 ? .white : .primary)
                            )
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Bar Chart
    private var barChartSection: some View {
        VStack(alignment: .leading) {
            Text("直近7日間")
                .font(.headline)
                .padding(.horizontal)

            let last7DaysStats = statsForLast7Days()

            Chart {
                ForEach(last7DaysStats) { stat in
                    BarMark(
                        x: .value("Day", stat.date, unit: .day),
                        y: .value("Value", displayMode == .count ? Double(stat.count) : stat.duration / 60.0) // minutes
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday())
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
    }

    // MARK: - Donut Chart
    private var donutChartSection: some View {
        VStack(alignment: .leading) {
            Text("カテゴリ別実績")
                .font(.headline)
                .padding(.horizontal)

            let categoryStats = statsByCategory()

            if categoryStats.isEmpty {
                Text("データがありません")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart {
                    ForEach(categoryStats) { stat in
                        SectorMark(
                            angle: .value("Value", displayMode == .count ? Double(stat.count) : stat.duration / 60.0),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(colorForCategory(stat))
                        .annotation(position: .overlay) {
                            // Optional: annotations could go here, but omitted to prevent clutter
                        }
                    }
                }
                .chartBackground { chartProxy in
                    GeometryReader { geometry in
                        if let plotFrame = chartProxy.plotFrame {
                            let frame = geometry[plotFrame]
                            VStack {
                                Text("Total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if displayMode == .count {
                                    Text("\(categoryStats.map { $0.count }.reduce(0, +)) 回")
                                        .font(.title2.bold())
                                } else {
                                    let totalMinutes = categoryStats.map { $0.duration }.reduce(0, +) / 60.0
                                    Text(formatMinutes(totalMinutes))
                                        .font(.title2.bold())
                                }
                            }
                            .position(x: frame.midX, y: frame.midY)
                        }
                    }
                }
                .frame(height: 250)
                .padding()

                // Legend
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], alignment: .leading) {
                    ForEach(categoryStats) { stat in
                        HStack {
                            Circle()
                                .fill(colorForCategory(stat))
                                .frame(width: 10, height: 10)
                            Text(stat.name)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers
    private func daysInCurrentMonth() -> [Date?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        // Pad to end of week
        let remainder = days.count % 7
        if remainder > 0 {
            days.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }

        return days
    }

    private func statForDate(_ date: Date) -> DailyStat {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let sessionsForDay = groupedSessionsByDay[startOfDay] ?? []
        let count = sessionsForDay.count
        let duration = sessionsForDay.reduce(0) { $0 + $1.duration }
        return DailyStat(date: date, count: count, duration: duration)
    }

    private func colorIntensity(for stat: DailyStat) -> Double {
        if displayMode == .count {
            if stat.count == 0 { return 0 }
            if stat.count < 3 { return 0.3 }
            if stat.count < 6 { return 0.6 }
            return 1.0
        } else {
            if stat.duration == 0 { return 0 }
            let hours = stat.duration / 3600
            if hours < 1 { return 0.3 }
            if hours < 3 { return 0.6 }
            return 1.0
        }
    }

    private func statsForLast7Days() -> [DailyStat] {
        var stats: [DailyStat] = []
        let calendar = Calendar.current

        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                stats.append(statForDate(date))
            }
        }
        return stats
    }

    private func statsByCategory() -> [CategoryStat] {
        var statsDict: [String: CategoryStat] = [:]

        for session in sessions {
            let categoryName = session.task?.category?.name ?? "未分類"
            let colorHex = session.task?.category?.themeColorHex

            if var existing = statsDict[categoryName] {
                existing.count += 1
                existing.duration += session.duration
                statsDict[categoryName] = existing
            } else {
                statsDict[categoryName] = CategoryStat(name: categoryName, count: 1, duration: session.duration, colorHex: colorHex)
            }
        }

        return Array(statsDict.values).sorted(by: { $0.count > $1.count })
    }

    private func colorForCategory(_ stat: CategoryStat) -> Color {
        if let hex = stat.colorHex, let color = Color(hex: hex) {
            return color
        }

        // Generate a deterministic random color or fallback
        var hasher = Hasher()
        hasher.combine(stat.name)
        let hash = abs(hasher.finalize())
        let colors: [Color] = [.blue, .orange, .purple, .pink, .yellow, .cyan, .mint, .indigo]
        return colors[hash % colors.count]
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hrs = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hrs > 0 {
            return "\(hrs)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

#Preview {
    ReflectView()
}
