import Foundation
import SwiftData

@Model
final class Task {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool

    @Relationship(deleteRule: .cascade, inverse: \WorkSession.task)
    var workSessions: [WorkSession] = []

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

@Model
final class WorkSession {
    @Attribute(.unique) var id: UUID
    var task: Task?
    var startTime: Date
    var durationMinutes: Int

    init(id: UUID = UUID(), startTime: Date, durationMinutes: Int, task: Task? = nil) {
        self.id = id
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.task = task
    }
}
