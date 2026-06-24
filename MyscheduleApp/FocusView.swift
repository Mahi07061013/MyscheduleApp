import SwiftUI
import SwiftData

struct FocusView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTasks: [Task]

    var incompleteTasks: [Task] {
        allTasks.filter { $0.status != .done }
    }

    @State private var selectedTask: Task?

    // Timer state
    private let defaultDuration: TimeInterval = 1500 // 25 minutes
    @State private var timeRemaining: TimeInterval = 1500
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var showingAlert = false

    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        return 1.0 - (timeRemaining / defaultDuration)
    }

    var body: some View {
        VStack {
            if !incompleteTasks.isEmpty {
                Picker("Task", selection: $selectedTask) {
                    Text("Select a task").tag(Task?.none)
                    ForEach(incompleteTasks) { task in
                        Text(task.title).tag(Task?.some(task))
                    }
                }
                .pickerStyle(.menu)
                .padding()
            } else {
                Text("No tasks available")
                    .padding()
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(lineWidth: 20.0)
                    .opacity(0.3)
                    .foregroundColor(.gray)

                Circle()
                    .trim(from: 0.0, to: CGFloat(min(self.progress, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 20.0, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: progress)

                Text(timeString)
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
            }
            .padding(40)

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
                        .background(isRunning ? Color.yellow : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    resetTimer()
                }) {
                    Text("Reset")
                        .font(.title2)
                        .padding()
                        .frame(width: 120)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.bottom, 50)

            Spacer()
        }
        .onAppear {
            if selectedTask == nil {
                selectedTask = incompleteTasks.first
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .alert("お疲れ様でした！", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {
                resetTimer()
            }
        } message: {
            Text("ポモドーロセッションが完了しました。")
        }
    }

    private func startTimer() {
        isRunning = true
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
    }

    private func resetTimer() {
        pauseTimer()
        timeRemaining = defaultDuration
    }

    private func timerFinished() {
        pauseTimer()

        let newSession = PomodoroSession(date: Date(), duration: defaultDuration, task: selectedTask)
        modelContext.insert(newSession)

        showingAlert = true
    }
}

#Preview {
    FocusView()
        .modelContainer(for: [TaskCategory.self, Task.self, PomodoroSession.self, Tag.self], inMemory: true)
}
