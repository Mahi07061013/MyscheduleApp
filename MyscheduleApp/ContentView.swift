//
//  ContentView.swift
//  MyscheduleApp
//
//  Created by Kato Mahiro on 2026/06/15.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskCategory.orderIndex) private var categories: [TaskCategory]
    @Query private var tasks: [Task]

    @State private var newTaskTitle: String = ""
    @State private var selectedCategory: TaskCategory?
    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var categoryToDelete: TaskCategory?

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

                HStack {
                    TextField("Enter task title", text: $newTaskTitle)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addTask()
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()

                List {
                    ForEach(tasks.filter { $0.category?.id == selectedCategory?.id }) { task in
                        Text(task.title)
                    }
                    .onDelete(perform: deleteTasks)
                }
            }
            .navigationTitle("Tasks")
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

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let newTask = Task(title: title, category: selectedCategory)
        modelContext.insert(newTask)
        newTaskTitle = ""
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

#Preview {
    ContentView()
        .modelContainer(for: [TaskCategory.self, Task.self, WorkSession.self], inMemory: true)
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

        let providers = info.itemProviders
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
