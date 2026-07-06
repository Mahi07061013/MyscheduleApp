import SwiftUI
import SwiftData
import UserNotifications

enum FocusMode: String, CaseIterable {
    case focus = "集中"
    case rest = "休憩"
}

struct FocusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) var timerManager
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
                return task.isRest == true
            } else {
                return task.isRest == false && task.category?.id == selectedCategoryForFocus?.id
            }
        }
    }

    @State private var showingStopAlert = false
    @State private var showingInlineTaskAlert = false
    @State private var newInlineTaskTitle = ""

    var body: some View {
        @Bindable var bindableTimerManager = timerManager
        NavigationStack {
            VStack {
                Picker("モード", selection: $focusMode) {
                    ForEach(FocusMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .disabled(timerManager.isRunning)
                .onChange(of: focusMode) { _, _ in
                    selectedTask = incompleteTasks.first
                }

                FocusHeaderView(
                    focusMode: focusMode,
                    categories: categories,
                    incompleteTasks: incompleteTasks,
                    selectedCategoryForFocus: $selectedCategoryForFocus,
                    selectedTask: $selectedTask,
                    newInlineTaskTitle: $newInlineTaskTitle,
                    showingInlineTaskAlert: $showingInlineTaskAlert,
                    timerManager: timerManager
                )

                Spacer()

                FocusTimerView(
                    timerManager: timerManager,
                    bindableTimerManager: timerManager,
                    focusMode: focusMode
                )

                if selectedTask == nil {
                    Text("タスクを設定してください")
                        .foregroundColor(.red)
                        .padding(.bottom, 10)
                }

                FocusControlsView(
                    timerManager: timerManager,
                    selectedTask: selectedTask,
                    showingStopAlert: $showingStopAlert
                )

                Spacer()
            }
            .onAppear {
                timerManager.requestNotificationAuthorization()
                if selectedTask == nil {
                    selectedTask = incompleteTasks.first
                }
                if !timerManager.isRunning && timerManager.timeRemaining == 1500 && timerManager.defaultDurationMinutes != 25 {
                    timerManager.timeRemaining = timerManager.defaultDuration
                } else if !timerManager.isRunning && timerManager.timeRemaining != timerManager.defaultDuration {
                    // keep it
                } else if !timerManager.isRunning {
                    timerManager.timeRemaining = timerManager.defaultDuration
                }
            }
            .alert("本当にやめますか？", isPresented: $showingStopAlert) {
                Button("やめる", role: .destructive) {
                    timerManager.resetTimer()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("進行状況は保存されません。")
            }
            .alert("新規タスク", isPresented: $showingInlineTaskAlert) {
                TextField("タスク名", text: $newInlineTaskTitle)
                Button("追加") {
                    let title = newInlineTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        let newTask = Task(title: title, category: selectedCategoryForFocus, isRest: focusMode == .rest)
                        modelContext.insert(newTask)
                        selectedTask = newTask
                    }
                }
                Button("キャンセル", role: .cancel) { }
            }
            .sheet(isPresented: $bindableTimerManager.showingMoodSheet) {
                NavigationStack {
                    VStack(spacing: 20) {
                        Text("今の気分は？")
                            .font(.headline)
                        HStack(spacing: 16) {
                            ForEach(1...5, id: \.self) { rating in
                                Button(action: {
                                    saveSession(with: rating)
                                }) {
                                    Text(moodEmoji(for: rating))
                                        .font(.system(size: 40))
                                }
                            }
                        }
                    }
                    .padding()
                    .presentationDetents([.fraction(0.3)])
                }
            }
            .sheet(isPresented: $isShowingAddTaskSheet) {
                AddTaskView(selectedCategory: selectedCategoryForFocus, initialIsRest: focusMode == .rest, showCategoryCreation: focusMode == .focus)
            }
        }
    }

    private func moodEmoji(for rating: Int) -> String {
        switch rating {
        case 1: return "😫"
        case 2: return "🙁"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "🤩"
        default: return "😐"
        }
    }

    private func saveSession(with moodRating: Int) {
        let newSession = PomodoroSession(date: Date(), duration: timerManager.defaultDuration, task: selectedTask, moodRating: moodRating)
        modelContext.insert(newSession)

        timerManager.showingMoodSheet = false
        timerManager.resetTimer()
    }

struct FocusHeaderView: View {
    let focusMode: FocusMode
    let categories: [TaskCategory]
    let incompleteTasks: [Task]
    @Binding var selectedCategoryForFocus: TaskCategory?
    @Binding var selectedTask: Task?
    @Binding var newInlineTaskTitle: String
    @Binding var showingInlineTaskAlert: Bool
    let timerManager: TimerManager

    var body: some View {
        HStack {
            if focusMode == .focus {
                Picker("タブ", selection: $selectedCategoryForFocus) {
                    Text("未分類").tag(TaskCategory?.none)
                    ForEach(categories) { category in
                        Text(category.name).tag(TaskCategory?.some(category))
                    }
                }
                .pickerStyle(.menu)
                .disabled(timerManager.isRunning)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedCategoryForFocus?.themeColorHex != nil ? Color(hex: selectedCategoryForFocus!.themeColorHex!)! : Color.gray, lineWidth: 2)
                )
                .background(selectedCategoryForFocus?.themeColorHex != nil ? Color(hex: selectedCategoryForFocus!.themeColorHex!)!.opacity(0.1) : Color.clear)
                .onChange(of: selectedCategoryForFocus) { _, _ in
                    selectedTask = incompleteTasks.first
                }
            }

            if !incompleteTasks.isEmpty {
                Menu {
                    Picker("Task", selection: $selectedTask) {
                        ForEach(incompleteTasks) { task in
                            Text(task.title).tag(Task?.some(task))
                        }
                    }

                    Button(action: {
                        newInlineTaskTitle = ""
                        showingInlineTaskAlert = true
                    }) {
                        Label("新規タスク", systemImage: "plus")
                    }
                } label: {
                    HStack {
                        Text(selectedTask?.title ?? "Select a task")
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                    }
                }
                .disabled(timerManager.isRunning)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedCategoryForFocus?.themeColorHex != nil ? Color(hex: selectedCategoryForFocus!.themeColorHex!)! : Color.gray, lineWidth: 2)
                )
                .background(selectedCategoryForFocus?.themeColorHex != nil ? Color(hex: selectedCategoryForFocus!.themeColorHex!)!.opacity(0.1) : Color.clear)
            } else {
                Text("No tasks available")
                    .foregroundColor(.secondary)

                Button(action: {
                    newInlineTaskTitle = ""
                    showingInlineTaskAlert = true
                }) {
                    Image(systemName: "plus")
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }

            Spacer()

            if let task = selectedTask {
                VStack(alignment: .trailing, spacing: 2) {
                    let elapsedSeconds = task.pomodoroSessions?.reduce(0) { $0 + $1.duration } ?? 0
                    let totalEstimatedSeconds = Double(task.estimatedSessions * timerManager.defaultDurationMinutes * 60)
                    let remainingSeconds = totalEstimatedSeconds - elapsedSeconds

                    let elapsedHours = Int(elapsedSeconds) / 3600
                    let elapsedMins = (Int(elapsedSeconds) % 3600) / 60
                    let elapsedText = elapsedHours > 0 ? "\(elapsedHours)h \(elapsedMins)m" : "\(elapsedMins)m"

                    let remAbs = Int(abs(remainingSeconds))
                    let remHours = remAbs / 3600
                    let remMins = (remAbs % 3600) / 60
                    let remPrefix = remainingSeconds < 0 ? "-" : ""
                    let remText = remHours > 0 ? "\(remPrefix)\(remHours)h \(remMins)m" : "\(remPrefix)\(remMins)m"

                    Text("Elapsed: \(elapsedText)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Remaining: \(remText)")
                        .font(.caption2)
                        .foregroundColor(remainingSeconds < 0 ? .red : .secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct FocusTimerView: View {
    let timerManager: TimerManager
    @Bindable var bindableTimerManager: TimerManager
    let focusMode: FocusMode

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 20.0)
                .opacity(0.3)
                .foregroundColor(.gray)

            Circle()
                .trim(from: 0.0, to: CGFloat(min(timerManager.progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 20.0, lineCap: .round, lineJoin: .round))
                .foregroundColor(focusMode == .focus ? .blue : .green)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: timerManager.progress)

            Menu {
                Picker("時間", selection: $bindableTimerManager.defaultDurationMinutes) {
                    ForEach(Array(stride(from: 5, through: 60, by: 5)), id: \.self) { minutes in
                        Text("\(minutes)分").tag(minutes)
                    }
                }
            } label: {
                Text(timerManager.timeString)
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .disabled(timerManager.isRunning)
            .onChange(of: timerManager.defaultDurationMinutes) { _, _ in
                if !timerManager.isRunning && timerManager.timeRemaining == timerManager.defaultDuration {
                    timerManager.timeRemaining = timerManager.defaultDuration
                } else if !timerManager.isRunning {
                     timerManager.timeRemaining = timerManager.defaultDuration
                }
            }
        }
        .padding(40)
    }
}

struct FocusControlsView: View {
    let timerManager: TimerManager
    let selectedTask: Task?
    @Binding var showingStopAlert: Bool

    var body: some View {
        HStack(spacing: 30) {
            Button(action: {
                if timerManager.isRunning {
                    timerManager.pauseTimer()
                } else {
                    timerManager.startTimer()
                }
            }) {
                Text(timerManager.isRunning ? "Pause" : "Start")
                    .font(.title2)
                    .padding()
                    .frame(width: 120)
                    .background(timerManager.isRunning ? Color.yellow : (selectedTask == nil ? Color.gray : Color.blue))
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
            .disabled(!timerManager.isRunning && timerManager.timeRemaining == timerManager.defaultDuration)
        }
        .padding(.bottom, 50)
    }
}
}

#Preview {
    FocusView()
        .modelContainer(for: [TaskCategory.self, Task.self, PomodoroSession.self, Tag.self], inMemory: true)
}
