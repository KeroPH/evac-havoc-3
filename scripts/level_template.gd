extends Node2D

var PausePopup = preload("res://scenes/pause_popup.tscn")
var DialogWindow = preload("res://scenes/dialog.tscn")

export var dialogue_text = []
export var next_scene = "res://scenes/menu.tscn"
export(PackedScene) var helicopter_scene

# Optional per-level fuel overrides (-1 means use defaults from Player scene)
export(float, -1, 100000) var fuel_max_override := -1.0
export(float, -1, 100000) var starting_fuel := -1.0
export(bool) var debug_logs := false
var _dbg_accum := 0.0

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
		var candidate = helicopter_scene.instance()
		var compatible := false
		if candidate != null:
			# Consider compatible if it emits the expected fuel signal (i.e., extends Player)
			compatible = candidate.has_signal("remaining_fuel")
		if compatible and is_instance_valid(old_player):
			var parent = old_player.get_parent()
			var pos = old_player.position
			# Remove old first to avoid duplicate names; then add the new one as 'player'
			parent.remove_child(old_player)
			old_player.queue_free()
			candidate.name = "player"
			candidate.position = pos
			parent.add_child(candidate)
		else:
			# Keep the original player if the selected scene is not a proper Player variant
			if is_instance_valid(candidate):
				candidate.queue_free()

	# Connect gauge after we know which player is present and apply fuel overrides
	var player = get_node_or_null("player")
	var gauge = get_node_or_null("ui/gauge")
	if player != null and player.has_signal("remaining_fuel") and gauge != null:
		# Apply per-level overrides (safe even after Player._ready())
		var fmax := float(player.fuel_max)
		if fuel_max_override >= 0.0:
			fmax = max(0.001, float(fuel_max_override))
			player.fuel_max = fmax
		var fval := fmax # default start full
		if starting_fuel >= 0.0:
			fval = clamp(float(starting_fuel), 0.0, fmax)
		player.fuel = fval

		player.connect("remaining_fuel", gauge, "_on_fuel_update")
		# Also connect once more on the next idle frame to avoid timing edge cases
		call_deferred("_deferred_connect")
		# Initialize gauge to the actual starting fuel level
		gauge._on_fuel_update(clamp(fval / max(0.001, fmax), 0.0, 1.0))
	else:
		push_warning("level_template: Player does not provide remaining_fuel signal; gauge will not update.")

func _deferred_connect():
	var player = get_node_or_null("player")
	var gauge = get_node_or_null("ui/gauge")
	if player != null and gauge != null:
		if not player.is_connected("remaining_fuel", gauge, "_on_fuel_update"):
			player.connect("remaining_fuel", gauge, "_on_fuel_update")
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
	if debug_logs:
		_dbg_accum += delta
		if _dbg_accum >= 0.5:
			_dbg_accum = 0.0
			var player = get_node_or_null("player")
			var gauge = get_node_or_null("ui/gauge")
			var connected := false
			if player != null and gauge != null:
				connected = player.is_connected("remaining_fuel", gauge, "_on_fuel_update")
			var fmax := 1.0
			var fval := 0.0
			if player != null:
				if "fuel_max" in player:
					fmax = max(0.001, float(player.fuel_max))
				if "fuel" in player:
					fval = float(player.fuel)
			print("[level] paused=", str(get_tree().paused), " connected=", str(connected), " fuel=", String(fval), "/", String(fmax))

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
