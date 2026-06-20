import Foundation
import SwiftData

@Model
final class TaskCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var orderIndex: Int

    @Relationship(deleteRule: .cascade, inverse: \Task.category)
    var tasks: [Task] = []

    init(id: UUID = UUID(), name: String, orderIndex: Int) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
    }
}

@Model
final class Task {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool

    @Relationship(deleteRule: .cascade, inverse: \WorkSession.task)
    var workSessions: [WorkSession] = []

    var category: TaskCategory?

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, category: TaskCategory? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.category = category
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
