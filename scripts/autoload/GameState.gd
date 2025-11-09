extends Node

const Task := preload("res://scripts/models/Task.gd")

signal xp_changed(new_xp: int)
signal dino_level_changed(new_level: int)
signal task_completed(task_id: int)

const SAVE_PATH := "user://habit_evolution_save.json"
const ALLOWED_XP_VALUES := [5, 10, 15, 20]
const LEVEL_THRESHOLDS := [0, 50, 150, 300]

var tasks: Array[Task] = []
var total_xp: int = 0
var dino_level: int = 1

var _next_task_id: int = 1

func _ready() -> void:
    load_state()
    _recalculate_internal_counters()

func add_task(name: String, difficulty_xp: int, schedule_type: String, times_per_week_target: int = 0, group: String = "") -> Task:
    if difficulty_xp not in ALLOWED_XP_VALUES:
        push_warning("Invalid XP value for task. Using default 5 XP.")
        difficulty_xp = 5
    var task := Task.new()
    task.id = _next_task_id
    task.name = name.strip_edges()
    task.difficulty_xp = difficulty_xp
    task.schedule_type = schedule_type
    task.times_per_week_target = times_per_week_target if schedule_type == "times_per_week" else 0
    task.group = group.strip_edges()
    task.completions = []
    tasks.append(task)
    _next_task_id += 1
    save_state()
    return task

func remove_task(id: int) -> void:
    for i in range(tasks.size() - 1, -1, -1):
        if tasks[i].id == id:
            tasks.remove_at(i)
            break
    save_state()

func get_task(id: int) -> Task:
    for task in tasks:
        if task.id == id:
            return task
    return null

func complete_task_for_today(id: int) -> void:
    var task := get_task(id)
    if task == null:
        return
    var today := _get_today_string()
    if task.completions.has(today):
        return
    if task.schedule_type == "weekly" and _count_completions_in_current_week(task) >= 1:
        return
    task.completions.append(today)
    total_xp += task.difficulty_xp
    _update_dino_level()
    emit_signal("task_completed", id)
    emit_signal("xp_changed", total_xp)
    save_state()

func get_today_tasks() -> Array:
    var today_tasks: Array[Task] = []
    for task in tasks:
        match task.schedule_type:
            "daily":
                today_tasks.append(task)
            "weekly":
                if get_weekly_progress(task) == 0:
                    today_tasks.append(task)
            "times_per_week":
                if get_times_per_week_progress(task) < task.times_per_week_target or task.times_per_week_target <= 0:
                    today_tasks.append(task)
    return today_tasks

func get_weekly_tasks() -> Array:
    var weekly: Array[Task] = []
    for task in tasks:
        if task.schedule_type == "weekly":
            weekly.append(task)
    return weekly

func get_times_per_week_tasks() -> Array:
    var list: Array[Task] = []
    for task in tasks:
        if task.schedule_type == "times_per_week":
            list.append(task)
    return list

func get_times_per_week_progress(task: Task) -> int:
    return _count_completions_in_current_week(task)

func get_weekly_progress(task: Task) -> int:
    return _count_completions_in_current_week(task)

func has_completed_today(task: Task) -> bool:
    var today := _get_today_string()
    return task.completions.has(today)

func save_state() -> void:
    var task_dicts: Array = []
    for task in tasks:
        task_dicts.append(task.to_dict())
    var data := {
        "tasks": task_dicts,
        "total_xp": total_xp,
        "dino_level": dino_level,
        "next_task_id": _next_task_id
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
        file.close()

func load_state() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        tasks = []
        total_xp = 0
        dino_level = 1
        _next_task_id = 1
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var content := file.get_as_text()
    file.close()
    var result: Variant = JSON.parse_string(content)
    if typeof(result) != TYPE_DICTIONARY:
        tasks = []
        total_xp = 0
        dino_level = 1
        _next_task_id = 1
        return
    tasks = []
    for task_data in result.get("tasks", []):
        if typeof(task_data) == TYPE_DICTIONARY:
            tasks.append(Task.from_dict(task_data))
    total_xp = int(result.get("total_xp", 0))
    dino_level = int(result.get("dino_level", 1))
    _next_task_id = int(result.get("next_task_id", _determine_next_task_id()))
    _update_dino_level(false)

func _determine_next_task_id() -> int:
    var highest := 0
    for task in tasks:
        highest = max(highest, task.id)
    return highest + 1

func _update_dino_level(emit_signal_flag: bool = true) -> void:
    var new_level := _calculate_dino_level()
    if new_level != dino_level:
        dino_level = new_level
        if emit_signal_flag:
            emit_signal("dino_level_changed", dino_level)
    elif emit_signal_flag:
        emit_signal("dino_level_changed", dino_level)

func _calculate_dino_level() -> int:
    var level := 1
    for i in range(LEVEL_THRESHOLDS.size()):
        if total_xp >= LEVEL_THRESHOLDS[i]:
            level = i + 1
    return level

func _recalculate_internal_counters() -> void:
    _next_task_id = _determine_next_task_id()
    _update_dino_level(false)

func _get_today_string() -> String:
    var date_dict := Time.get_datetime_dict_from_system()
    return _date_dict_to_string(date_dict)

func _date_dict_to_string(date_dict: Dictionary) -> String:
    return "%04d-%02d-%02d" % [date_dict["year"], date_dict["month"], date_dict["day"]]

func _count_completions_in_current_week(task: Task) -> int:
    var count := 0
    var current_week_id := _get_week_id_from_string(_get_today_string())
    for date_string in task.completions:
        if _get_week_id_from_string(date_string) == current_week_id:
            count += 1
    return count

func _get_week_id_from_string(date_string: String) -> String:
    var parts := date_string.split("-")
    if parts.size() < 3:
        return ""
    var dt := {
        "year": int(parts[0]),
        "month": int(parts[1]),
        "day": int(parts[2]),
        "hour": 0,
        "minute": 0,
        "second": 0
    }
    var unix_time := Time.get_unix_time_from_datetime_dict(dt)
    var full_dict := Time.get_datetime_dict_from_unix_time(unix_time)
    var weekday := int(full_dict.get("weekday", 0))
    # Align the date to the Monday of its week (0 = Sunday in Godot's weekday representation).
    var days_from_monday := (weekday + 6) % 7
    var start_unix := unix_time - days_from_monday * 86400
    var start_dict := Time.get_datetime_dict_from_unix_time(start_unix)
    return _date_dict_to_string(start_dict)
