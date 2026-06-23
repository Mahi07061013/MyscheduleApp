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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Categories Tab UI
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories) { category in
                            Text(category.name)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedCategory == category ? .white : .primary)
                                .cornerRadius(16)
                                .onTapGesture {
                                    withAnimation {
                                        selectedCategory = category
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        categoryToDelete = category
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                                .onDrag {
                                    NSItemProvider(object: category.id.uuidString as NSString)
                                }
                                .onDrop(of: [UTType.text], delegate: CategoryDropDelegate(item: category, categories: categories, onReorder: reorderCategories))
                        }

                        Button(action: {
                            isShowingAddCategoryAlert = true
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
            .alert("新しいカテゴリ", isPresented: $isShowingAddCategoryAlert) {
                TextField("カテゴリ名", text: $newCategoryName)
                Button("キャンセル", role: .cancel) {
                    newCategoryName = ""
                }
                Button("追加") {
                    addCategory()
                }
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let maxOrder = categories.map { $0.orderIndex }.max() ?? -1
        let newCategory = TaskCategory(name: name, orderIndex: maxOrder + 1)
        modelContext.insert(newCategory)
        newCategoryName = ""
        selectedCategory = newCategory
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

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var selectedCategory: TaskCategory?

    @State private var title: String = ""
    @State private var status: TaskStatus = .todo
    @State private var hasStartDate = false
    @State private var startDate = Date()
    @State private var hasPriority = false
    @State private var priority: TaskPriority = .medium

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
            category: selectedCategory
        )
        modelContext.insert(newTask)
        dismiss()
    }
}

struct TaskRowView: View {
    @Bindable var task: Task

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
                    .foregroundColor(task.status == .done ? .gray : .primary)
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
        .modelContainer(for: [TaskCategory.self, Task.self, WorkSession.self, Tag.self], inMemory: true)
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
