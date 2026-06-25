1. **Models.swift**
   - Add `isRest: Bool = false` to `Task`.
   - Update `init` method to handle `isRest`.

2. **TaskManagementView.swift**
   - In `AddTaskView`, add `initialIsRest: Bool = false` and `@State private var isRest: Bool = false`.
   - Add a `Toggle("休憩用タスク", isOn: $isRest)` inside the Task Info section.
   - Set `isRest` on `onAppear`.
   - In `saveTask()`, pass `isRest: isRest` to the new `Task` instance.

3. **ReflectView.swift**
   - Add a computed property `validSessions` that filters out `sessions` where `task?.isRest == true`.
   - Replace all existing usages of `sessions` (like in `sessionsByDate` and `categoryData`) with `validSessions` so rest tasks are not counted in graphs or stats.

4. **FocusView.swift**
   - Add a Picker for Focus/Rest mode (`"集中"`, `"休憩"`).
   - Filter `incompleteTasks` based on the selected mode.
   - Add a timer duration Picker (5, 10, ... 60 mins).
   - Show "タスクを設定してください" if no task is selected, and disable the Start button.
   - Add a "＋タスクを新しく作る" button to create tasks/categories directly.
   - Add a "やめる" button to stop the timer with a confirmation dialog (does not save session).
   - Add UserNotifications scheduling on start and cancellation on stop/reset.
   - Track background/foreground times using `scenePhase` to adjust the remaining time properly.

5. **Pre-commit Steps**
   - Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.

6. **Submit**
   - Submit the branch once all requirements are successfully met.
