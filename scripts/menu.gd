extends Control
onready var login_btn = $vbox/login

func _ready():
	var name = "Guest"
	if has_node("/root/score_manager"):
		name = get_node("/root/score_manager").get_player_name()
	if login_btn:
		login_btn.text = "LOGGED IN AS:\n\n" + str(name)

func _on_start_btn_up():
	get_tree().change_scene("res://scenes/level_select.tscn")

func _on_tut_btn_up():
	get_tree().change_scene("res://scenes/levels/tutorial.tscn")

func _on_quit_btn_up():
	get_tree().quit()

func _on_heli_btn_up():
	get_tree().change_scene("res://scenes/helicopter_select.tscn")

func _on_login_btn_up():
	get_tree().change_scene("res://scenes/login.tscn")

func _on_lb_btn_up():
	get_tree().change_scene("res://scenes/leaderboard.tscn")
