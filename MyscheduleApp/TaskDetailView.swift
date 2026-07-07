import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var task: Task

    @Query private var allTags: [Tag]
    @Query(sort: \TaskCategory.orderIndex) private var allCategories: [TaskCategory]

    @State private var isCreatingNewCategory = false
    @State private var newCategoryName = ""
    @State private var newTagName = ""
    @State private var newSubtaskTitle = ""

    let colorOptions: [(name: String, color: Color, hex: String?)] = [
        ("デフォルト", .primary, nil),
        ("赤", .red, Color.red.toHex()),
        ("青", .blue, Color.blue.toHex()),
        ("緑", .green, Color.green.toHex()),
        ("オレンジ", .orange, Color.orange.toHex()),
        ("紫", .purple, Color.purple.toHex())
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("タスク情報")) {
                    TextField("タイトル", text: $task.title)

                    Picker("ステータス", selection: $task.status) {
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }

                    Picker("文字色", selection: $task.textColorHex) {
                        ForEach(colorOptions, id: \.name) { option in
                            Text(option.name).tag(option.hex)
                        }
                    }

                    if !task.isRest {
                        Toggle("新しいタブを作成する", isOn: $isCreatingNewCategory)

                        if isCreatingNewCategory {
                            TextField("新しいタブ（カテゴリ）名", text: $newCategoryName)
                            Button("作成して選択") {
                                createNewCategory()
                            }
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        } else {
                            Picker("タブ", selection: $task.category) {
                                Text("未分類").tag(TaskCategory?.none)
                                ForEach(allCategories) { category in
                                    Text(category.name).tag(TaskCategory?.some(category))
                                }
                            }
                        }
                    }
                }

                Section(header: Text("日付")) {
                    DatePicker("開始日", selection: $task.startDate, displayedComponents: [.date, .hourAndMinute])

                    if let completedDate = task.completedDate {
                        HStack {
                            Text("完了日時")
                            Spacer()
                            Text(completedDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("見積もり")) {
                    Stepper(value: $task.estimatedSessions, in: 1...20) {
                        Text("ポモドーロ数: \(task.estimatedSessions)")
                    }
                }

                Section(header: Text("優先度")) {
                    Picker("優先度", selection: $task.priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("タグ")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(allTags) { tag in
                                let isSelected = task.tags?.contains(where: { $0.id == tag.id }) ?? false
                                Text(tag.name)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .cornerRadius(12)
                                    .onTapGesture {
                                        if task.tags == nil {
                                            task.tags = []
                                        }
                                        if isSelected {
                                            task.tags?.removeAll(where: { $0.id == tag.id })
                                        } else {
                                            task.tags?.append(tag)
                                        }
                                    }
                            }
                        }
                    }
                    HStack {
                        TextField("新しいタグを追加", text: $newTagName)
                        Button("追加") {
                            let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !name.isEmpty && !allTags.contains(where: { $0.name == name }) {
                                let newTag = Tag(name: name)
                                modelContext.insert(newTag)
                                if task.tags == nil {
                                    task.tags = []
                                }
                                task.tags?.append(newTag)
                                newTagName = ""
                            }
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section(header: Text("サブタスク")) {
                    if let subtasks = task.subtasks {
                        ForEach(subtasks.sorted(by: { $0.orderIndex < $1.orderIndex }), id: \.id) { subtask in
                            Text(subtask.title)
                        }
                        .onDelete(perform: deleteSubtasks)
                    }

                    HStack {
                        TextField("サブタスクを追加", text: $newSubtaskTitle)
                        Button("追加") {
                            let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !title.isEmpty {
                                let newSubtask = Task(title: title, parentTask: task, orderIndex: (task.subtasks?.count ?? 0))
                                if task.subtasks == nil {
                                    task.subtasks = []
                                }
                                task.subtasks?.append(newSubtask)
                                newSubtaskTitle = ""
                            }
                        }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("タスク詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .onChange(of: task.status) { oldValue, newValue in
                if newValue == .done {
                    task.completedDate = Date()
                } else if newValue != .done && oldValue == .done {
                    // 達成から変更された場合、完了日時をクリアするかどうか。通常はクリアする。
                    task.completedDate = nil
                }
            }
        }
    }

    private func createNewCategory() {
        let trimmedNewCategory = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNewCategory.isEmpty {
            let maxOrder = allCategories.map { $0.orderIndex }.max() ?? -1
            let newCategory = TaskCategory(name: trimmedNewCategory, orderIndex: maxOrder + 1)
            modelContext.insert(newCategory)
            task.category = newCategory
            isCreatingNewCategory = false
            newCategoryName = ""
        }
    }

    private func deleteSubtasks(offsets: IndexSet) {
        guard let subtasks = task.subtasks else { return }
        let sortedSubtasks = subtasks.sorted(by: { $0.orderIndex < $1.orderIndex })
        for index in offsets {
            modelContext.delete(sortedSubtasks[index])
        }
    }
}
