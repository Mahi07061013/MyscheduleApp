//
//  ContentView.swift
//  MyscheduleApp
//
//  Created by Kato Mahiro on 2026/06/15.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskCategory.orderIndex) private var categories: [TaskCategory]
    @Query private var tasks: [Task]

    @State private var newTaskTitle: String = ""
    @State private var selectedCategory: TaskCategory?

    @State private var isShowingAddCategoryAlert = false
    @State private var newCategoryName = ""

    @State private var categoryToDelete: TaskCategory?
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Category Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories) { category in
                            Text(category.name)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedCategory == category ? .white : .primary)
                                .cornerRadius(20)
                                .onTapGesture {
                                    selectedCategory = category
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        categoryToDelete = category
                                        isShowingDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .onDrag {
                                    NSItemProvider(object: category.id.uuidString as NSString)
                                }
                                .onDrop(of: [.plainText], isTargeted: nil) { providers in
                                    handleDrop(providers: providers, target: category)
                                }
                        }

                        Button(action: {
                            isShowingAddCategoryAlert = true
                        }) {
                            Image(systemName: "plus")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(20)
                        }
                    }
                    .padding()
                }
                .onChange(of: categories) { _, newCategories in
                    if selectedCategory == nil, let first = newCategories.first {
                        selectedCategory = first
                    } else if let selected = selectedCategory, !newCategories.contains(selected) {
                        selectedCategory = newCategories.first
                    }
                }

                // Add Task
                HStack {
                    TextField("Enter task title", text: $newTaskTitle)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addTask()
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategory == nil)
                }
                .padding()

                // Task List
                List {
                    ForEach(filteredTasks) { task in
                        Text(task.title)
                    }
                    .onDelete(perform: deleteTasks)
                }
            }
            .navigationTitle("Tasks")
            .alert("Add Category", isPresented: $isShowingAddCategoryAlert) {
                TextField("Category Name", text: $newCategoryName)
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                }
                Button("Add") {
                    addCategory()
                }
            }
            .confirmationDialog(
                "Delete Category?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                    }
                }
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this category and all its tasks?")
            }
        }
        .onAppear {
            if selectedCategory == nil {
                selectedCategory = categories.first
            }
        }
    }

    private var filteredTasks: [Task] {
        guard let selected = selectedCategory else { return [] }
        return tasks.filter { $0.category == selected }
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let newIndex = categories.map { $0.orderIndex }.max() ?? -1
        let newCategory = TaskCategory(name: name, orderIndex: newIndex + 1)
        modelContext.insert(newCategory)
        newCategoryName = ""
        selectedCategory = newCategory
    }

    private func deleteCategory(_ category: TaskCategory) {
        modelContext.delete(category)
        categoryToDelete = nil
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let category = selectedCategory else { return }

        let newTask = Task(title: title, category: category)
        modelContext.insert(newTask)
        newTaskTitle = ""
    }

    private func deleteTasks(offsets: IndexSet) {
        let tasksToDelete = filteredTasks
        withAnimation {
            for index in offsets {
                modelContext.delete(tasksToDelete[index])
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider], target: TaskCategory) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadObject(ofClass: NSString.self) { string, _ in
            guard let idString = string as? String,
                  let id = UUID(uuidString: idString) else { return }

            DispatchQueue.main.async {
                guard let source = categories.first(where: { $0.id == id }), source != target else { return }

                guard let sourceIndex = categories.firstIndex(of: source),
                      let targetIndex = categories.firstIndex(of: target) else { return }

                var newCategories = categories
                newCategories.remove(at: sourceIndex)
                newCategories.insert(source, at: targetIndex)

                for (index, category) in newCategories.enumerated() {
                    category.orderIndex = index
                }
            }
        }
        return true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [TaskCategory.self, Task.self, WorkSession.self], inMemory: true)
}
