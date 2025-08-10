extends Control

onready var name_edit = $center/vbox/name_edit
onready var save_btn = $center/vbox/save_btn
onready var back_btn = $center/vbox/back_btn

const MENU_SCENE := "res://scenes/menu.tscn"

func _ready():
	if has_node("center/vbox/name_edit"):
		name_edit.text = score_manager.get_player_name()
	save_btn.connect("button_up", self, "_on_save")
	back_btn.connect("button_up", self, "_on_back")

func _on_save():
	score_manager.set_player_name(name_edit.text)
	get_tree().change_scene(MENU_SCENE)

func _on_back():
	get_tree().change_scene(MENU_SCENE)
