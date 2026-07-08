import SwiftUI
import SwiftData
import UserNotifications

enum FocusMode: String, CaseIterable {
    case focus = "集中"
    case rest = "休憩"
}

struct FocusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var timerManager
    @Query private var allTasks: [Task]

    @State private var focusMode: FocusMode = .focus
    @State private var selectedCategoryForFocus: TaskCategory?
    @State private var selectedTask: Task?
    @State private var isShowingAddTaskSheet = false
    @State private var showingNewTaskAlert = false
    @State private var newTaskName = ""

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

    @State private var showingStopAlert = false

    var progress: Double {
        return timerManager.progress
    }

    var timeString: String {
        let minutes = Int(timerManager.timeRemaining) / 60
        let seconds = Int(timerManager.timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
                .disabled(timerManager.isRunning)
                .onChange(of: focusMode) { _, _ in
                    selectedTask = incompleteTasks.first
                }

                HStack(spacing: 12) {
                    if focusMode == .focus {
                        Picker("タブ", selection: $selectedCategoryForFocus) {
                            Text("未分類").tag(TaskCategory?.none)
                            ForEach(categories) { category in
                                Text(category.name).tag(TaskCategory?.some(category))
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(8)
                        .background(
                            Color(hex: selectedCategoryForFocus?.themeColorHex ?? "") ?? Color.clear
                        )
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary, lineWidth: 1))
                        .disabled(timerManager.isRunning)
                        .onChange(of: selectedCategoryForFocus) { _, _ in
                            selectedTask = incompleteTasks.first
                        }
                    }

                    Menu {
                        Picker("Task", selection: $selectedTask) {
                            Text("Select a task").tag(Task?.none)
                            ForEach(incompleteTasks) { task in
                                Text(task.title).tag(Task?.some(task))
                            }
                        }
                        Button("新規タスク") {
                            newTaskName = ""
                            showingNewTaskAlert = true
                        }
                    } label: {
                        HStack {
                            Text(selectedTask?.title ?? (incompleteTasks.isEmpty ? "No tasks available" : "Select a task"))
                            Image(systemName: "chevron.down")
                        }
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary, lineWidth: 1))
                    }
                    .disabled(timerManager.isRunning)

                    Spacer()

                    if let selectedTask = selectedTask {
                        VStack(alignment: .trailing, spacing: 4) {
                            let totalSeconds = selectedTask.pomodoroSessions?.reduce(0) { $0 + $1.duration } ?? 0
                            let totalMinutes = Int(totalSeconds) / 60
                            let spentHours = totalMinutes / 60
                            let spentMins = totalMinutes % 60

                            let estimatedTotalSeconds = TimeInterval(selectedTask.estimatedSessions * timerManager.defaultDurationMinutes * 60)
                            let remainingSeconds = estimatedTotalSeconds - totalSeconds
                            let isNegative = remainingSeconds < 0
                            let absRemainingMinutes = Int(abs(remainingSeconds)) / 60
                            let remainingHours = absRemainingMinutes / 60
                            let remainingMins = absRemainingMinutes % 60

                            Text("\(spentHours)時間\(spentMins)分")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(isNegative ? "-" : "")\(remainingHours)時間\(remainingMins)分")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
                        Picker("時間", selection: Bindable(timerManager).defaultDurationMinutes) {
                            ForEach(Array(stride(from: 5, through: 60, by: 5)), id: \.self) { minutes in
                                Text("\(minutes)分").tag(minutes)
                            }
                        }
                    } label: {
                        Text(timeString)
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

                if selectedTask == nil {
                    Text("タスクを設定してください")
                        .foregroundColor(.red)
                        .padding(.bottom, 10)
                }

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
            .sheet(isPresented: Bindable(timerManager).showingFinishedAlert) {
                VStack(spacing: 20) {
                    Text("お疲れ様でした！\n今の気分は？")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding(.top, 30)

                    HStack(spacing: 15) {
                        let emojis = ["😫", "🙁", "😐", "🙂", "🤩"]
                        ForEach(0..<5, id: \.self) { index in
                            Button(action: {
                                let newSession = PomodoroSession(
                                    date: Date(),
                                    duration: timerManager.defaultDuration,
                                    moodRating: index + 1,
                                    task: selectedTask
                                )
                                modelContext.insert(newSession)
                                timerManager.showingFinishedAlert = false
                                timerManager.resetTimer()
                            }) {
                                Text(emojis[index])
                                    .font(.system(size: 40))
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
                .padding()
                .presentationDetents([.fraction(0.3)])
                .interactiveDismissDisabled()
            }
            .alert("本当にやめますか？", isPresented: $showingStopAlert) {
                Button("やめる", role: .destructive) {
                    timerManager.stopAndResetTimer()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("進行状況は保存されません。")
            }
            .sheet(isPresented: $isShowingAddTaskSheet) {
                AddTaskView(selectedCategory: selectedCategoryForFocus, initialIsRest: focusMode == .rest, showCategoryCreation: focusMode == .focus)
            }
            .alert("新規タスク", isPresented: $showingNewTaskAlert) {
                TextField("タスク名", text: $newTaskName)
                Button("キャンセル", role: .cancel) {}
                Button("追加") {
                    let task = Task(
                        title: newTaskName.isEmpty ? "New Task" : newTaskName,
                        category: selectedCategoryForFocus,
                        isRest: focusMode == .rest
                    )
                    modelContext.insert(task)
                    selectedTask = task
                }
            }
        }
    }
}

#Preview {
    FocusView()
        .modelContainer(for: [TaskCategory.self, Task.self, PomodoroSession.self, Tag.self], inMemory: true)
        .environment(TimerManager())
}
