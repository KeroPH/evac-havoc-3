extends Control

onready var levels = $center/vbox/levels
onready var list = $center/vbox/list
onready var back_btn = $center/vbox/back_btn

const MENU_SCENE := "res://scenes/menu.tscn"

func _ready():
	# Godot 3: OptionButton.add_item(text, id=-1)
	levels.add_item("Level 01")
	levels.add_item("Level 02")
	levels.add_item("Level 03")
	levels.add_item("Level 04")
	levels.add_item("Tutorial")
	levels.connect("item_selected", self, "_on_level_selected")
	back_btn.connect("button_up", self, "_on_back")
	_levels_refresh(0)

func _on_level_selected(idx):
	_levels_refresh(idx)

func _levels_refresh(idx):
	var level_id = _idx_to_level_id(idx)
	list.clear()
	var sm = _sm()
	var entries = []
	if sm != null:
		entries = sm.get_leaderboard(level_id)
	for i in range(entries.size()):
		var e = entries[i]
		var name = str(e.get("name", "?"))
		var t = float(e.get("time", -1))
		var line = str(i+1) + ".  " + name + " — " + String(t) + "s"
		list.add_item(line)

func _idx_to_level_id(idx):
	match idx:
		0:
			return "01"
		1:
			return "02"
		2:
			return "03"
		3:
			return "04"
		4:
			return "tutorial"
		_:
			return "01"

func _on_back():
	get_tree().change_scene(MENU_SCENE)

func _sm():
	if has_node("/root/score_manager"):
		return get_node("/root/score_manager")
	return null
