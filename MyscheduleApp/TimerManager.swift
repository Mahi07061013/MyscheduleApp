import Foundation
import SwiftUI
import UserNotifications

@Observable
final class TimerManager {
    var defaultDurationMinutes: Int = 25 {
        didSet {
            UserDefaults.standard.set(defaultDurationMinutes, forKey: "defaultDurationMinutes")
        }
    }

    var timeRemaining: TimeInterval = 1500
    var isRunning = false
    var showingFinishedAlert = false
    var backgroundDate: Date?

    var defaultDuration: TimeInterval {
        TimeInterval(defaultDurationMinutes * 60)
    }

    var progress: Double {
        return 1.0 - (timeRemaining / defaultDuration)
    }

    @ObservationIgnored private var timer: Timer?

    init() {
        let savedDuration = UserDefaults.standard.integer(forKey: "defaultDurationMinutes")
        self.defaultDurationMinutes = savedDuration == 0 ? 25 : savedDuration
        self.timeRemaining = TimeInterval(self.defaultDurationMinutes * 60)
    }

    func requestNotificationAuthorization() {
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

    func stopAndResetTimer() {
        pauseTimer()
        timeRemaining = defaultDuration
    }

    private func timerFinished() {
        pauseTimer()
        timeRemaining = 0
        showingFinishedAlert = true
    }

    func handleScenePhaseBackground() {
        if isRunning {
            backgroundDate = Date()
        }
    }

    func handleScenePhaseActive() {
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
