import SwiftUI
import SwiftData
import UserNotifications

enum FocusMode: String, CaseIterable {
    case focus = "集中"
    case rest = "休憩"
}

struct FocusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Query private var allTasks: [Task]

    @State private var focusMode: FocusMode = .focus
    @State private var selectedCategoryForFocus: TaskCategory?
    @State private var selectedTask: Task?
    @State private var isShowingAddTaskSheet = false

    @Query(sort: \TaskCategory.orderIndex) private var categories: [TaskCategory]

    var incompleteTasks: [Task] {
        allTasks.filter { task in
            guard task.status != .done else { return false }
            if focusMode == .rest {
                return task.isRest
            } else {
                return !task.isRest && task.category?.id == selectedCategoryForFocus?.id
            }
        }
    }

    // Timer state
    @AppStorage("defaultDurationMinutes") private var defaultDurationMinutes: Int = 25
    @State private var timeRemaining: TimeInterval = 1500
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var showingFinishedAlert = false
    @State private var showingStopAlert = false

    @State private var backgroundDate: Date?

    var defaultDuration: TimeInterval {
        TimeInterval(defaultDurationMinutes * 60)
    }

    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        return 1.0 - (timeRemaining / defaultDuration)
    }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("モード", selection: $focusMode) {
                    ForEach(FocusMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: focusMode) { _, _ in
                    selectedTask = incompleteTasks.first
                }

                if focusMode == .focus {
                    HStack {
                        Picker("タブ", selection: $selectedCategoryForFocus) {
                            Text("未分類").tag(TaskCategory?.none)
                            ForEach(categories) { category in
                                Text(category.name).tag(TaskCategory?.some(category))
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedCategoryForFocus) { _, _ in
                            selectedTask = incompleteTasks.first
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                HStack {
                    if !incompleteTasks.isEmpty {
                        Picker("Task", selection: $selectedTask) {
                            Text("Select a task").tag(Task?.none)
                            ForEach(incompleteTasks) { task in
                                Text(task.title).tag(Task?.some(task))
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Text("No tasks available")
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        isShowingAddTaskSheet = true
                    }) {
                        Image(systemName: "plus")
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(lineWidth: 20.0)
                        .opacity(0.3)
                        .foregroundColor(.gray)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                        .stroke(style: StrokeStyle(lineWidth: 20.0, lineCap: .round, lineJoin: .round))
                        .foregroundColor(focusMode == .focus ? .blue : .green)
                        .rotationEffect(Angle(degrees: 270.0))
                        .animation(.linear, value: progress)

                    Menu {
                        Picker("時間", selection: $defaultDurationMinutes) {
                            ForEach(Array(stride(from: 5, through: 60, by: 5)), id: \.self) { minutes in
                                Text("\(minutes)分").tag(minutes)
                            }
                        }
                    } label: {
                        Text(timeString)
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    .disabled(isRunning)
                    .onChange(of: defaultDurationMinutes) { _, _ in
                        if !isRunning && timeRemaining == defaultDuration {
                            timeRemaining = defaultDuration
                        } else if !isRunning {
                             timeRemaining = defaultDuration
                        }
                    }
                }
                .padding(40)

                if selectedTask == nil {
                    Text("タスクを設定してください")
                        .foregroundColor(.red)
                        .padding(.bottom, 10)
                }

                HStack(spacing: 30) {
                    Button(action: {
                        if isRunning {
                            pauseTimer()
                        } else {
                            startTimer()
                        }
                    }) {
                        Text(isRunning ? "Pause" : "Start")
                            .font(.title2)
                            .padding()
                            .frame(width: 120)
                            .background(isRunning ? Color.yellow : (selectedTask == nil ? Color.gray : Color.blue))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(selectedTask == nil)

                    Button(action: {
                        showingStopAlert = true
                    }) {
                        Text("やめる")
                            .font(.title2)
                            .padding()
                            .frame(width: 120)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isRunning && timeRemaining == defaultDuration)
                }
                .padding(.bottom, 50)

                Spacer()
            }
            .onAppear {
                requestNotificationAuthorization()
                if selectedTask == nil {
                    selectedTask = incompleteTasks.first
                }
                if !isRunning && timeRemaining == 1500 && defaultDurationMinutes != 25 {
                    timeRemaining = defaultDuration
                } else if !isRunning && timeRemaining != defaultDuration {
                    // keep it
                } else if !isRunning {
                    timeRemaining = defaultDuration
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    if isRunning {
                        backgroundDate = Date()
                    }
                } else if newPhase == .active {
                    if let bgDate = backgroundDate, isRunning {
                        let elapsed = Date().timeIntervalSince(bgDate)
                        timeRemaining -= elapsed
                        if timeRemaining <= 0 {
                            timeRemaining = 0
                            timerFinished()
                        }
                    }
                    backgroundDate = nil
                }
            }
            .alert("お疲れ様でした！", isPresented: $showingFinishedAlert) {
                Button("OK", role: .cancel) {
                    resetTimer()
                }
            } message: {
                Text("ポモドーロセッションが完了しました。")
            }
            .alert("本当にやめますか？", isPresented: $showingStopAlert) {
                Button("やめる", role: .destructive) {
                    stopAndResetTimer()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("進行状況は保存されません。")
            }
            .sheet(isPresented: $isShowingAddTaskSheet) {
                AddTaskView(selectedCategory: selectedCategoryForFocus, initialIsRest: focusMode == .rest, showCategoryCreation: focusMode == .focus)
            }
        }
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification() {
        cancelNotification()

        let content = UNMutableNotificationContent()
        content.title = "時間です！"
        content.body = "タイマーが終了しました。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeRemaining > 0 ? timeRemaining : 1, repeats: false)
        let request = UNNotificationRequest(identifier: "timerFinished", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timerFinished"])
    }

    private func startTimer() {
        isRunning = true
        scheduleNotification()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timerFinished()
            }
        }
    }

    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        cancelNotification()
    }

    private func resetTimer() {
        pauseTimer()
        timeRemaining = defaultDuration
    }

    private func stopAndResetTimer() {
        pauseTimer()
        timeRemaining = defaultDuration
    }

    private func timerFinished() {
        pauseTimer()
        timeRemaining = 0

        let newSession = PomodoroSession(date: Date(), duration: defaultDuration, task: selectedTask)
        modelContext.insert(newSession)

        showingFinishedAlert = true
    }
}

#Preview {
    FocusView()
        .modelContainer(for: [TaskCategory.self, Task.self, PomodoroSession.self, Tag.self], inMemory: true)
}
