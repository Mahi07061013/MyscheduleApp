//
//  TaskManagementView.swift
//  MyscheduleApp
//
//  Created by Kato Mahiro on 2026/06/15.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TaskManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskCategory.orderIndex) private var categories: [TaskCategory]
    @Query private var tasks: [Task]

    @State private var selectedCategory: TaskCategory?
    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var categoryToDelete: TaskCategory?
    @State private var isShowingAddTaskSheet = false
    @State private var isShowingAddCategorySheet = false

    private var listBackgroundColor: Color {
        if let hex = selectedCategory?.themeColorHex, let color = Color(hex: hex) {
            return color.opacity(0.15)
        }
        return Color.clear
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Categories Tab UI
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories) { category in
                            CategoryTabItemView(
                                category: category,
                                selectedCategory: selectedCategory,
                                onTap: {
                                    withAnimation {
                                        selectedCategory = category
                                    }
                                },
                                onDelete: {
                                    categoryToDelete = category
                                }
                            )
                            .onDrag {
                                NSItemProvider(object: category.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.text], delegate: CategoryDropDelegate(item: category, categories: categories, onReorder: reorderCategories))
                        }

                        Button(action: {
                            isShowingAddCategorySheet = true
                        }) {
                            Image(systemName: "plus")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(16)
                        }
                    }
                    .padding()
                }

                List {
                    ForEach(tasks.filter { $0.category?.id == selectedCategory?.id }) { task in
                        TaskRowView(task: task)
                    }
                    .onDelete(perform: deleteTasks)
                }
                .scrollContentBackground(.hidden)
                .background(listBackgroundColor)
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddTaskSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddCategorySheet) {
                AddCategorySheet(
                    categories: categories,
                    modelContext: modelContext,
                    onSave: { newCategory in
                        selectedCategory = newCategory
                    }
                )
            }
            .alert("確認", isPresented: Binding<Bool>(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            )) {
                Button("キャンセル", role: .cancel) { }
                Button("削除", role: .destructive) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                    }
                }
            } message: {
                Text("このカテゴリと紐づくタスクをすべて削除しますか？")
            }
            .onAppear {
                if selectedCategory == nil {
                    selectedCategory = categories.first
                }
            }
            .onChange(of: categories) { _, newCategories in
                if selectedCategory == nil || !newCategories.contains(where: { $0.id == selectedCategory?.id }) {
                    selectedCategory = newCategories.first
                }
            }
            .sheet(isPresented: $isShowingAddTaskSheet) {
                AddTaskView(selectedCategory: selectedCategory)
            }
        }
    }

    private func deleteCategory(_ category: TaskCategory) {
        modelContext.delete(category)
        categoryToDelete = nil
        if selectedCategory == category {
            selectedCategory = categories.first(where: { $0.id != category.id })
        }
    }

    private func reorderCategories(from source: TaskCategory, to destination: TaskCategory) {
        var orderedCategories = categories
        guard let sourceIndex = orderedCategories.firstIndex(of: source),
              let destinationIndex = orderedCategories.firstIndex(of: destination) else { return }

        orderedCategories.remove(at: sourceIndex)
        orderedCategories.insert(source, at: destinationIndex)

        for (index, cat) in orderedCategories.enumerated() {
            cat.orderIndex = index
        }
    }

    private func deleteTasks(offsets: IndexSet) {
        let filteredTasks = tasks.filter { $0.category?.id == selectedCategory?.id }
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredTasks[index])
            }
        }
    }
}

struct CategoryTabItemView: View {
    let category: TaskCategory
    let selectedCategory: TaskCategory?
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(category.name)

            if completedPomodoros > 0 {
                Text("\(completedPomodoros)")
                    .font(.caption2).bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeBackgroundColor)
                    .foregroundColor(foregroundColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(16)
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private var completedPomodoros: Int {
        category.tasks.reduce(0) { total, task in
            total + (task.pomodoroSessions?.count ?? 0)
        }
    }

    private var isSelected: Bool {
        selectedCategory == category
    }

    private var backgroundColor: Color {
        if isSelected {
            if let hex = category.themeColorHex, let color = Color(hex: hex) {
                return color
            }
            return .blue
        } else {
            return Color.gray.opacity(0.2)
        }
    }

    private var badgeBackgroundColor: Color {
        Color.white.opacity(isSelected ? 0.3 : 0.8)
    }

    private var foregroundColor: Color {
        isSelected ? .white : .primary
    }
}

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    var categories: [TaskCategory]
    var modelContext: ModelContext
    var onSave: (TaskCategory) -> Void

    @State private var newCategoryName = ""
    @State private var selectedThemeColor: Color = .blue

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("カテゴリ情報")) {
                    TextField("カテゴリ名", text: $newCategoryName)
                    ColorPicker("テーマカラー", selection: $selectedThemeColor)
                }
            }
            .navigationTitle("新しいカテゴリ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            let maxOrder = categories.map { $0.orderIndex }.max() ?? -1
                            let newCategory = TaskCategory(name: name, orderIndex: maxOrder + 1, themeColorHex: selectedThemeColor.toHex())
                            modelContext.insert(newCategory)
                            onSave(newCategory)
                            dismiss()
                        }
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allTags: [Tag]

    var selectedCategory: TaskCategory?

    @State private var title: String = ""
    @State private var status: TaskStatus = .todo
    @State private var hasStartDate = false
    @State private var startDate = Date()
    @State private var hasPriority = false
    @State private var priority: TaskPriority = .medium

    @State private var selectedTags = Set<Tag>()
    @State private var newTagName = ""

    @State private var subtasks: [String] = []
    @State private var newSubtaskTitle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("タスク情報")) {
                    TextField("タイトル", text: $title)

                    Picker("ステータス", selection: $status) {
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }

                Section(header: Text("日付")) {
                    Toggle("開始日を設定", isOn: $hasStartDate)
                    if hasStartDate {
                        DatePicker("開始日", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section(header: Text("優先度")) {
                    Toggle("優先度を設定", isOn: $hasPriority)
                    if hasPriority {
                        Picker("優先度", selection: $priority) {
                            ForEach(TaskPriority.allCases, id: \.self) { priority in
                                Text(priority.rawValue).tag(priority)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }

                Section(header: Text("タグ")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(allTags) { tag in
                                Text(tag.name)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedTags.contains(tag) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedTags.contains(tag) ? .white : .primary)
                                    .cornerRadius(12)
                                    .onTapGesture {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
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
                                selectedTags.insert(newTag)
                                newTagName = ""
                            }
                        }
                        .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section(header: Text("サブタスク")) {
                    ForEach(subtasks.indices, id: \.self) { index in
                        Text(subtasks[index])
                    }
                    .onDelete { offsets in
                        subtasks.remove(atOffsets: offsets)
                    }

                    HStack {
                        TextField("サブタスクを追加", text: $newSubtaskTitle)
                        Button("追加") {
                            let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !title.isEmpty {
                                subtasks.append(title)
                                newSubtaskTitle = ""
                            }
                        }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("タスク追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveTask() {
        let newTask = Task(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            startDate: hasStartDate ? startDate : nil,
            priority: hasPriority ? priority : nil,
            category: selectedCategory,
            tags: Array(selectedTags)
        )

        if !subtasks.isEmpty {
            let taskSubtasks = subtasks.map { Task(title: $0, parentTask: newTask) }
            newTask.subtasks = taskSubtasks
        }

        modelContext.insert(newTask)
        dismiss()
    }
}

struct TaskRowView: View {
    @Bindable var task: Task

    let colorOptions: [(name: String, color: Color, hex: String?)] = [
        ("デフォルト", .primary, nil),
        ("赤", .red, Color.red.toHex()),
        ("青", .blue, Color.blue.toHex()),
        ("緑", .green, Color.green.toHex()),
        ("オレンジ", .orange, Color.orange.toHex()),
        ("紫", .purple, Color.purple.toHex())
    ]

    private var textColor: Color {
        if task.status == .done {
            return .gray
        }
        if let hex = task.textColorHex, let customColor = Color(hex: hex) {
            return customColor
        }
        return .primary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: {
                toggleStatus()
            }) {
                Image(systemName: statusIconName)
                    .foregroundColor(statusColor)
                    .font(.title2)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.status == .done)
                    .foregroundColor(textColor)
                    .font(.headline)

                if task.startDate != nil || task.priority != nil {
                    HStack(spacing: 8) {
                        if let startDate = task.startDate {
                            Label(startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        }

                        if let priority = task.priority {
                            Label(priority.rawValue, systemImage: "exclamationmark.circle")
                                .foregroundColor(priorityColor(priority))
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Menu("文字色を変更") {
                ForEach(0..<colorOptions.count, id: \.self) { index in
                    Button {
                        task.textColorHex = colorOptions[index].hex
                    } label: {
                        HStack {
                            Text(colorOptions[index].name)
                            Spacer()
                            if task.textColorHex == colorOptions[index].hex {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
    }

    private var statusIconName: String {
        switch task.status {
        case .todo: return "circle"
        case .inProgress: return "circle.dashed"
        case .done: return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .todo: return .gray
        case .inProgress: return .blue
        case .done: return .green
        }
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }

    private func toggleStatus() {
        withAnimation {
            switch task.status {
            case .todo:
                task.status = .done
            case .inProgress:
                task.status = .done
            case .done:
                task.status = .todo
            }
        }
    }
}

#Preview {
    TaskManagementView()
        .modelContainer(for: [TaskCategory.self, Task.self, PomodoroSession.self, Tag.self], inMemory: true)
}

struct CategoryDropDelegate: DropDelegate {
    let item: TaskCategory
    var categories: [TaskCategory]
    let onReorder: (TaskCategory, TaskCategory) -> Void

    func dropEntered(info: DropInfo) {
        // Implementation for drop entered if needed
    }

    func performDrop(info: DropInfo) -> Bool {
        guard info.hasItemsConforming(to: [UTType.text]) else { return false }

        let providers = info.itemProviders(for: [UTType.text])
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.text.identifier) }) {
            _ = provider.loadObject(ofClass: String.self) { string, error in
                if let idString = string, let id = UUID(uuidString: idString) {
                    DispatchQueue.main.async {
                        if let source = categories.first(where: { $0.id == id }) {
                            if source != item {
                                onReorder(source, item)
                            }
                        }
                    }
                }
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
