extends Control

@onready var tab_container: TabContainer = $MarginContainer/VBoxContainer/TabContainer

func _ready() -> void:
    tab_container.set_tab_title(0, "Tasks")
    tab_container.set_tab_title(1, "Sanctuary")
