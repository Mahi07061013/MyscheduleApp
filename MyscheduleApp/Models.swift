import Foundation
import SwiftData

enum TaskStatus: String, Codable, CaseIterable {
    case todo = "未着手"
    case inProgress = "進行中"
    case done = "達成"
}

enum TaskPriority: String, Codable, CaseIterable {
    case high = "高"
    case medium = "中"
    case low = "低"
}

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String

    @Relationship(inverse: \Task.tags)
    var tasks: [Task]?

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

@Model
final class TaskCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var orderIndex: Int
    var themeColorHex: String?

    @Relationship(deleteRule: .cascade, inverse: \Task.category)
    var tasks: [Task] = []

    init(id: UUID = UUID(), name: String, orderIndex: Int, themeColorHex: String? = nil) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
        self.themeColorHex = themeColorHex
    }
}

@Model
final class Task {
    @Attribute(.unique) var id: UUID
    var title: String
    var status: TaskStatus
    var startDate: Date
    var priority: TaskPriority
    var estimatedSessions: Int
    var estimatedMinutes: Int?
    var textColorHex: String?

    @Relationship(deleteRule: .cascade, inverse: \PomodoroSession.task)
    var pomodoroSessions: [PomodoroSession]?

    var category: TaskCategory?

    var tags: [Tag]?

    @Relationship(deleteRule: .cascade, inverse: \Task.parentTask)
    var subtasks: [Task]?

    var parentTask: Task?

    var isRest: Bool = false
    var orderIndex: Int = 0
    var completedDate: Date?

    init(id: UUID = UUID(), title: String, status: TaskStatus = .todo, startDate: Date = Date(), priority: TaskPriority = .low, estimatedSessions: Int = 1, estimatedMinutes: Int? = nil, textColorHex: String? = nil, category: TaskCategory? = nil, tags: [Tag]? = nil, subtasks: [Task]? = nil, parentTask: Task? = nil, isRest: Bool = false, orderIndex: Int = 0, completedDate: Date? = nil) {
        self.id = id
        self.title = title
        self.status = status
        self.startDate = startDate
        self.priority = priority
        self.estimatedSessions = estimatedSessions
        self.estimatedMinutes = estimatedMinutes
        self.textColorHex = textColorHex
        self.category = category
        self.tags = tags
        self.subtasks = subtasks
        self.parentTask = parentTask
        self.isRest = isRest
        self.orderIndex = orderIndex
        self.completedDate = completedDate
    }
}

@Model
final class PomodoroSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var duration: TimeInterval
    var moodRating: Int?
    var task: Task?

    init(id: UUID = UUID(), date: Date = Date(), duration: TimeInterval = 1500, moodRating: Int? = nil, task: Task? = nil) {
        self.id = id
        self.date = date
        self.duration = duration
        self.moodRating = moodRating
        self.task = task
    }
}
