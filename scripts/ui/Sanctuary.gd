extends Control

const LEVEL_TEXTURES := {
    1: "res://art/dino/dino_lvl1.png",
    2: "res://art/dino/dino_lvl2.png",
    3: "res://art/dino/dino_lvl3.png",
    4: "res://art/dino/dino_lvl4.png"
}

@onready var dino_texture: TextureRect = $Background/DinoHolder/DinoTexture
@onready var level_label: Label = $Background/DinoHolder/LevelLabel

func _ready() -> void:
    GameState.dino_level_changed.connect(_on_dino_level_changed)
    GameState.xp_changed.connect(_on_xp_changed)
    _refresh()

func _refresh() -> void:
    level_label.text = "Level %d\nTotal XP: %d" % [GameState.dino_level, GameState.total_xp]
    _update_dino_texture(GameState.dino_level)

func _on_dino_level_changed(new_level: int) -> void:
    _update_dino_texture(new_level)
    level_label.text = "Level %d\nTotal XP: %d" % [GameState.dino_level, GameState.total_xp]

func _on_xp_changed(_new_xp: int) -> void:
    level_label.text = "Level %d\nTotal XP: %d" % [GameState.dino_level, GameState.total_xp]

func _update_dino_texture(level: int) -> void:
    var target_level := _determine_texture_level(level)
    var path := LEVEL_TEXTURES.get(target_level, "")
    if path.is_empty():
        dino_texture.texture = null
        return
    if ResourceLoader.exists(path):
        dino_texture.texture = load(path)
    else:
        dino_texture.texture = null

func _determine_texture_level(level: int) -> int:
    var levels := LEVEL_TEXTURES.keys()
    levels.sort()
    var selected := levels[0]
    for lvl in levels:
        if level >= lvl:
            selected = lvl
    return selected
