extends Node2D

var PausePopup = preload("res://scenes/pause_popup.tscn")
var DialogWindow = preload("res://scenes/dialog.tscn")

export var dialogue_text = []
export var next_scene = "res://scenes/menu.tscn"
export(PackedScene) var helicopter_scene

var remaining_people


func _ready():
	# Mark level start for leaderboard timing
	var level_id = _detect_level_id()
	score_manager.start_level(level_id)
	# If a helicopter variant scene is provided, replace the placeholder $player
	if helicopter_scene == null:
		# Try to load saved selection
		var cf = ConfigFile.new()
		var err = cf.load("user://helicopter.cfg")
		if err == OK:
			var path = cf.get_value("helicopter", "scene_path", "")
			if typeof(path) == TYPE_STRING and path != "":
				if ResourceLoader.exists(path):
					helicopter_scene = load(path)

	if helicopter_scene != null:
		var old_player = $player
		var new_player = helicopter_scene.instance()
		new_player.name = "player"
		new_player.position = old_player.position
		old_player.get_parent().add_child_below_node(old_player, new_player)
		old_player.queue_free()

	# Connect gauge after we know which player is present
	$player.connect("remaining_fuel", $ui/gauge, "_on_fuel_update")
	$helipad.connect("body_entered", self, "_on_helipad_land")
	for person in get_tree().get_nodes_in_group("people"):
		person.connect("person_saved", self, "_on_person_saved")
	
	remaining_people = len(get_tree().get_nodes_in_group("people"))
	$ui/remain_label.text = "%d people left" % remaining_people
	
	if dialogue_text != []:
		var dialog = DialogWindow.instance()
		$ui.add_child(dialog)
		dialog.set_lines(dialogue_text)
		dialog.pause_mode = Node.PAUSE_MODE_PROCESS
		get_tree().set_pause(true)

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		_pause_game()

func _pause_game():
	var pause_menu = PausePopup.instance()
	$ui.add_child(pause_menu)
	pause_menu.pause_mode = Node.PAUSE_MODE_PROCESS
	pause_menu.connect("quit_game", self, "_on_quit_game")
	pause_menu.popup_centered()
	get_tree().set_pause(true)

func _on_quit_game():
	get_tree().quit()

func _on_person_saved():
	remaining_people -= 1
	$ui/remain_label.text = "%d people left" % remaining_people

func _on_helipad_land(body):
	if body is Player and remaining_people <= 0:
		# Finish timer and submit score
		var level_id = _detect_level_id()
		var seconds = score_manager.finish_level(level_id)
		if seconds >= 0.0:
			score_manager.submit_time(level_id, seconds)
		$applause.play()
		if next_scene != "":
			get_tree().set_pause(false)
			get_tree().change_scene(next_scene)

func _detect_level_id():
	# Extract level id from current scene path: scenes/levels/<id>.tscn
	var path = get_tree().current_scene.filename if get_tree().current_scene != null else ""
	if path.find("/levels/") != -1:
		var slash = path.find_last("/")
		var dot = path.find_last(".")
		if slash != -1 and dot != -1 and dot > slash:
			return path.substr(slash+1, dot - (slash+1))
	return "unknown"
