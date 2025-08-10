extends Control

onready var grid = $vbox/scroll/grid
onready var back_btn = $vbox/bottom/back_btn

const MENU_SCENE := "res://scenes/menu.tscn"
const LEVELS_DIR := "res://scenes/levels"

export(int) var columns := 3
export(bool) var debug_logs := false

func d(msg):
	if debug_logs:
		print("[level-select] ", msg)

func _ready():
	# Apply column count
	grid.columns = columns
	_populate()
	back_btn.connect("button_up", self, "_on_back")

func _on_back():
	get_tree().change_scene(MENU_SCENE)

func _populate():
	# Clear old
	for c in grid.get_children():
		c.queue_free()
	# Scan levels folder
	var paths = _scan_levels()
	# Sort paths by name
	paths.sort()
	for p in paths:
		var btn = Button.new()
		btn.text = _pretty_name_from_path(p)
		btn.rect_min_size = Vector2(200, 80)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.connect("button_up", self, "_on_level_btn", [p])
		grid.add_child(btn)

func _on_level_btn(level_path):
	if ResourceLoader.exists(level_path):
		get_tree().change_scene(level_path)
	else:
		d("missing: " + str(level_path))

func _scan_levels():
	var out = []
	var dir = Directory.new()
	var err = dir.open(LEVELS_DIR)
	if err != OK:
		d("cannot open levels dir: " + LEVELS_DIR)
		return out
	dir.list_dir_begin(true, true)
	var name = dir.get_next()
	while name != "":
		if not dir.current_is_dir():
			if name.ends_with(".tscn"):
				var full = LEVELS_DIR + "/" + name
				out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out

func _pretty_name_from_path(p):
	var f = p
	var slash = f.find_last("/")
	if slash != -1:
		f = f.substr(slash+1, f.length() - (slash+1))
	var dot = f.find_last(".")
	if dot != -1:
		f = f.substr(0, dot)
	f = f.replace("_", " ")
	return f
