import SwiftUI
import UserNotifications
import SwiftData

@Observable
final class TimerManager {
    var timeRemaining: TimeInterval = 1500
    var isRunning = false
    var defaultDurationMinutes: Int = 25
    var showingFinishedAlert = false
    var showingMoodSheet = false
    var backgroundDate: Date?

    @ObservationIgnored private var timer: Timer?

    var defaultDuration: TimeInterval {
        TimeInterval(defaultDurationMinutes * 60)
    }

    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        if defaultDuration == 0 { return 0 }
        return 1.0 - (timeRemaining / defaultDuration)
    }

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleNotification() {
        cancelNotification()
        let content = UNMutableNotificationContent()
        content.title = "時間です！"
        content.body = "タイマーが終了しました。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeRemaining > 0 ? timeRemaining : 1, repeats: false)
        let request = UNNotificationRequest(identifier: "timerFinished", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timerFinished"])
    }

    func startTimer() {
        isRunning = true
        scheduleNotification()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.timerFinished()
            }
        }
    }

    func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        cancelNotification()
    }

    func resetTimer() {
        pauseTimer()
        timeRemaining = defaultDuration
    }

    func timerFinished() {
        pauseTimer()
        timeRemaining = 0
        showingMoodSheet = true
    }

    func appEnteredBackground() {
        if isRunning {
            backgroundDate = Date()
        }
    }

    func appEnteredForeground() {
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
