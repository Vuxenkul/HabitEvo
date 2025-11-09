extends Control

const Task := preload("res://scripts/models/Task.gd")

const SCHEDULE_TYPES := {
    "Daily": "daily",
    "Weekly": "weekly",
    "X times/week": "times_per_week"
}

const DIFFICULTY_OPTIONS := {
    "Easy (5 XP)": 5,
    "Normal (10 XP)": 10,
    "Hard (15 XP)": 15,
    "Epic (20 XP)": 20
}

@onready var name_input: LineEdit = $MarginContainer/MainVBox/AddTaskPanel/AddTaskVBox/NameInput
@onready var schedule_option: OptionButton = $MarginContainer/MainVBox/AddTaskPanel/AddTaskVBox/ScheduleRow/ScheduleType
@onready var times_row: HBoxContainer = $MarginContainer/MainVBox/AddTaskPanel/AddTaskVBox/TimesRow
@onready var times_spin: SpinBox = $MarginContainer/MainVBox/AddTaskPanel/AddTaskVBox/TimesRow/TimesSpin
@onready var difficulty_option: OptionButton = $MarginContainer/MainVBox/AddTaskPanel/AddTaskVBox/DifficultyRow/DifficultyOption
@onready var group_input: LineEdit = $MarginContainer/MainVBox/AddTaskPanel/AddTaskVBox/GroupInput
@onready var add_task_button: Button = $MarginContainer/MainVBox/AddTaskPanel/AddTaskVBox/AddTaskButton
@onready var today_tasks_list: VBoxContainer = $MarginContainer/MainVBox/TodaySection/TodayTasksList
@onready var today_empty_label: Label = $MarginContainer/MainVBox/TodaySection/TodayEmpty
@onready var weekly_tasks_list: VBoxContainer = $MarginContainer/MainVBox/WeeklySection/WeeklyTasksList
@onready var weekly_empty_label: Label = $MarginContainer/MainVBox/WeeklySection/WeeklyEmpty
@onready var times_tasks_list: VBoxContainer = $MarginContainer/MainVBox/TimesSection/TimesTasksList
@onready var times_empty_label: Label = $MarginContainer/MainVBox/TimesSection/TimesEmpty

func _ready() -> void:
    _populate_schedule_option()
    _populate_difficulty_option()
    times_spin.min_value = 1
    times_spin.max_value = 14
    times_spin.step = 1
    schedule_option.item_selected.connect(_on_schedule_type_selected)
    add_task_button.pressed.connect(_on_add_task_pressed)
    GameState.task_completed.connect(_on_game_state_change)
    GameState.xp_changed.connect(_on_game_state_change)
    refresh_lists()
    _update_times_row_visibility()

func _populate_schedule_option() -> void:
    schedule_option.clear()
    for label in SCHEDULE_TYPES.keys():
        schedule_option.add_item(label)
        schedule_option.set_item_metadata(schedule_option.item_count - 1, SCHEDULE_TYPES[label])
    schedule_option.select(0)

func _populate_difficulty_option() -> void:
    difficulty_option.clear()
    for label in DIFFICULTY_OPTIONS.keys():
        difficulty_option.add_item(label)
        difficulty_option.set_item_metadata(difficulty_option.item_count - 1, DIFFICULTY_OPTIONS[label])
    difficulty_option.select(0)

func _on_schedule_type_selected(index: int) -> void:
    _update_times_row_visibility()

func _update_times_row_visibility() -> void:
    var schedule := schedule_option.get_selected_metadata()
    times_row.visible = schedule == "times_per_week"

func _on_add_task_pressed() -> void:
    var name := name_input.text.strip_edges()
    if name.is_empty():
        return
    var schedule := String(schedule_option.get_selected_metadata())
    var difficulty := int(difficulty_option.get_selected_metadata())
    var times_target := int(times_spin.value) if schedule == "times_per_week" else 0
    var group := group_input.text.strip_edges()
    GameState.add_task(name, difficulty, schedule, times_target, group)
    name_input.text = ""
    group_input.text = ""
    refresh_lists()

func refresh_lists() -> void:
    _populate_today_tasks()
    _populate_weekly_tasks()
    _populate_times_tasks()

func _populate_today_tasks() -> void:
    _clear_container(today_tasks_list)
    var tasks := GameState.get_today_tasks()
    today_empty_label.visible = tasks.is_empty()
    for task in tasks:
        var completed_today := GameState.has_completed_today(task)
        var weekly_done := task.schedule_type == "weekly" and GameState.get_weekly_progress(task) >= 1
        var row := _create_task_row(task, completed_today or weekly_done)
        today_tasks_list.add_child(row)

func _populate_weekly_tasks() -> void:
    _clear_container(weekly_tasks_list)
    var tasks := GameState.get_weekly_tasks()
    weekly_empty_label.visible = tasks.is_empty()
    for task in tasks:
        var progress := GameState.get_weekly_progress(task)
        var label := Label.new()
        var status := progress >= 1 ? "Completed for this week" : "Pending"
        label.text = "%s (%s) - %s" % [task.name, task.group, status]
        weekly_tasks_list.add_child(label)

func _populate_times_tasks() -> void:
    _clear_container(times_tasks_list)
    var tasks := GameState.get_times_per_week_tasks()
    times_empty_label.visible = tasks.is_empty()
    for task in tasks:
        var progress := GameState.get_times_per_week_progress(task)
        var label := Label.new()
        var reached := task.times_per_week_target > 0 and progress >= task.times_per_week_target
        var status := "%d / %d" % [progress, max(task.times_per_week_target, 1)]
        if reached:
            status += " ✅"
        label.text = "%s (%s) - %s" % [task.name, task.group, status]
        times_tasks_list.add_child(label)

func _create_task_row(task: Task, completed: bool) -> Control:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var name_label := Label.new()
    name_label.text = task.name
    name_label.add_theme_color_override("font_color", Color.WHITE)
    info.add_child(name_label)

    var meta_label := Label.new()
    var group_text := task.group.is_empty() ? "No group" : task.group
    meta_label.text = "%s • %d XP" % [group_text, task.difficulty_xp]
    info.add_child(meta_label)

    row.add_child(info)

    var button := Button.new()
    button.text = completed ? "Done" : "Complete"
    button.disabled = completed
    button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    var task_id := task.id
    if not completed:
        button.pressed.connect(func():
            GameState.complete_task_for_today(task_id)
        )
    row.add_child(button)
    return row

func _clear_container(container: VBoxContainer) -> void:
    for child in container.get_children():
        child.queue_free()

func _on_game_state_change(_value = null) -> void:
    refresh_lists()
