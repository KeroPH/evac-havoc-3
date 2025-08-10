extends Control

onready var preview_root = $preview
onready var viewport = $preview/vp
onready var name_label = $name
onready var prev_btn = $buttons/prev_btn
onready var next_btn = $buttons/next_btn
onready var confirm_btn = $buttons/confirm_btn

const MENU_SCENE := "res://scenes/menu.tscn"

var options = []
var index = 0
var preview_instance : Node = null

# Debug logging toggle
export(bool) var debug_logs = true

func d(msg):
	if debug_logs:
		print("[heli-select] ", msg)

func _ready():
	prev_btn.connect("button_up", self, "_on_prev")
	next_btn.connect("button_up", self, "_on_next")
	confirm_btn.connect("button_up", self, "_on_confirm")

	# Ensure the preview area never blocks button clicks
	if preview_root and preview_root is Control:
		preview_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ensure viewport matches container size
	if viewport:
		# Configure viewport for 2D previews and continuous updates
		viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
		viewport.usage = Viewport.USAGE_2D
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.size = preview_root.rect_size
		preview_root.connect("resized", self, "_on_preview_resized")

	_discover_options()

	# Keep only options that exist to avoid errors (Godot 3.x friendly)
	var filtered = []
	for o in options:
		if ResourceLoader.exists(o["path"]):
			filtered.append(o)
	options = filtered
	d("options after filter: " + str(options))
	if options.size() == 0:
		name_label.text = "No helicopters found"
		confirm_btn.disabled = true
		prev_btn.disabled = true
		next_btn.disabled = true
		d("no options available; controls disabled")
		return

	# Defer initial view until layout has a real size
	call_deferred("_initial_show")

func _initial_show():
	_on_preview_resized()
	_load_saved_selection()
	_update_view()

func _discover_options():
	var found = []

	# 1) Include base player if present
	var base_player = "res://scenes/player.tscn"
	if ResourceLoader.exists(base_player):
		found.append({"name": _pretty_name_from_path(base_player), "path": base_player})

	# 2) Scan helicopters folder for .tscn files
	var heli_dir = "res://scenes/helicopters"
	var heli_paths = _scan_directory_for_scenes(heli_dir)
	for p in heli_paths:
		# Avoid duplicates by path
		var duplicate = false
		for f in found:
			if f["path"] == p:
				duplicate = true
				break
		if not duplicate:
			found.append({"name": _pretty_name_from_path(p), "path": p})

	options = found
	d("discovered options: " + str(options))

func _scan_directory_for_scenes(path):
	var results = []
	var dir = Directory.new()
	var err = dir.open(path)
	if err != OK:
		d("scan: directory not found -> " + str(path))
		return results
	dir.list_dir_begin(true, true)
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			if fname.ends_with(".tscn"):
				var full_path = path + "/" + fname
				if ResourceLoader.exists(full_path):
					results.append(full_path)
		fname = dir.get_next()
	dir.list_dir_end()
	return results

func _pretty_name_from_path(p):
	# Extract filename without extension
	var f = p
	# Get just the file segment
	var slash = f.find_last("/")
	if slash != -1:
		f = f.substr(slash + 1, f.length() - (slash + 1))
	var dot = f.find_last(".")
	if dot != -1:
		f = f.substr(0, dot)
	var parts = f.split("_")
	for i in range(parts.size()):
		var s = parts[i]
		if s != "":
			parts[i] = s.substr(0, 1).to_upper() + s.substr(1)
	return parts.join(" ")

func _on_prev():
	_set_index(index - 1)
	d("prev -> index=" + str(index))
	_update_view()

func _on_next():
	_set_index(index + 1)
	d("next -> index=" + str(index))
	_update_view()

func _set_index(i):
	if options.size() == 0:
		index = 0
		return
	var n = options.size()
	# Manual wrap to avoid any modulo surprises
	if i < 0:
		index = n - 1
	elif i >= n:
		index = 0
	else:
		index = i
	d("set_index(" + str(i) + ") => " + str(index))

func _preview(path: String):
	# Clear previous preview (both container and viewport)
	for c in preview_root.get_children():
		if c != viewport:
			c.queue_free()
	if viewport:
		var kids = viewport.get_children()
		for k in kids:
			k.queue_free()
	preview_instance = null

	if not ResourceLoader.exists(path):
		d("preview missing or invalid path: " + str(path))
		return
	var scene = load(path)
	var inst = scene.instance()
	inst.pause_mode = Node.PAUSE_MODE_PROCESS
	if viewport and inst is Node:
		viewport.add_child(inst)
		if inst is Node2D:
			call_deferred("_fit_node2d_preview", inst)
		elif inst is Control:
			# Put a sub-root Control to hold it, so anchors work inside the viewport
			var holder = Control.new()
			holder.name = "holder"
			holder.rect_min_size = viewport.size
			holder.size_flags_horizontal = 0
			holder.size_flags_vertical = 0
			viewport.add_child(holder)
			holder.add_child(inst)
			inst.set_anchors_and_margins_preset(Control.PRESET_CENTER)
			call_deferred("_fit_control_in_holder", holder, inst)
	else:
		preview_root.add_child(inst)
		if inst is Node2D:
			inst.position = Vector2(preview_root.rect_size.x * 0.5, preview_root.rect_size.y * 0.6)
		elif inst is Control:
			inst.size_flags_horizontal = 0
			inst.size_flags_vertical = 0
			inst.set_anchors_and_margins_preset(Control.PRESET_CENTER)
			call_deferred("_fit_control_preview", inst)
	preview_instance = inst
	d("preview instantiated: " + str(path))

func _on_preview_resized():
	if viewport:
		viewport.size = preview_root.rect_size
		# Re-fit current preview if any
		if is_instance_valid(preview_instance):
			if preview_instance is Node2D:
				_fit_node2d_preview(preview_instance)
			elif preview_instance is Control:
				# If we used a holder, try to find it and refit
				for c in viewport.get_children():
					if c is Control and c.name == "holder":
						_fit_control_in_holder(c, preview_instance)
						break

func _fit_control_preview(ctrl: Control):
	if not is_instance_valid(ctrl):
		return
	# Compute a scale to fit into preview area with padding
	var avail = preview_root.rect_size
	var size = ctrl.rect_size
	var pad = 0.85
	var sx = 1.0
	var sy = 1.0
	if size.x > 0:
		sx = (avail.x * pad) / float(size.x)
	if size.y > 0:
		sy = (avail.y * pad) / float(size.y)
	var s = min(sx, sy)
	if s < 1.0:
		ctrl.rect_scale = Vector2(s, s)
	else:
		ctrl.rect_scale = Vector2(1, 1)
	# Center after scaling
	var scaled = Vector2(size.x * ctrl.rect_scale.x, size.y * ctrl.rect_scale.y)
	ctrl.rect_position = Vector2(
		(avail.x - scaled.x) * 0.5,
		(avail.y - scaled.y) * 0.5
	)

func _fit_node2d_preview(n: Node2D):
	if not is_instance_valid(n):
		return
	var avail = viewport.size if viewport else preview_root.rect_size
	# Try to compute a representative size via get_item_rect if present
	var rect = Rect2(Vector2.ZERO, Vector2.ONE)
	if n.has_method("get_item_rect"):
		rect = n.get_item_rect()
	else:
		# Fallback approximate bounds
		rect.size = Vector2(256, 256)
	var pad = 0.85
	var sx = (avail.x * pad) / max(1.0, rect.size.x)
	var sy = (avail.y * pad) / max(1.0, rect.size.y)
	var s = min(sx, sy)
	n.scale = Vector2(s, s)
	n.position = Vector2(avail.x * 0.5, avail.y * 0.5)

func _fit_control_in_holder(holder: Control, ctrl: Control):
	if not is_instance_valid(holder) or not is_instance_valid(ctrl):
		return
	holder.rect_min_size = preview_root.rect_size
	ctrl.rect_scale = Vector2(1, 1)
	var avail = holder.rect_min_size
	var size = ctrl.rect_size
	var pad = 0.85
	var sx = (avail.x * pad) / max(1.0, size.x)
	var sy = (avail.y * pad) / max(1.0, size.y)
	var s = min(sx, sy)
	ctrl.rect_scale = Vector2(s, s)
	var scaled = Vector2(size.x * s, size.y * s)
	ctrl.rect_position = Vector2((avail.x - scaled.x) * 0.5, (avail.y - scaled.y) * 0.5)

func _on_confirm():
	var path = options[index]["path"]
	var label = options[index]["name"]
	var cf = ConfigFile.new()
	cf.load("user://helicopter.cfg")
	cf.set_value("helicopter", "scene_path", path)
	cf.set_value("helicopter", "name", label)
	cf.save("user://helicopter.cfg")
	d("confirmed selection: " + label + " -> " + path)
	get_tree().change_scene(MENU_SCENE)

func _load_saved_selection():
	var cf = ConfigFile.new()
	var err = cf.load("user://helicopter.cfg")
	if err == OK:
		var path = cf.get_value("helicopter", "scene_path", "")
		for i in range(options.size()):
			if options[i]["path"] == path:
				_set_index(i)
				break
		d("loaded saved selection: " + str(path) + "; using index " + str(index))

func _update_view():
	if options.size() == 0:
		# Nothing to show; keep UI visible and do not attempt preview
		name_label.text = "No helicopters found"
		d("update_view -> no options")
		return
	name_label.text = str(options[index]["name"])
	_preview(options[index]["path"])
	d("update_view -> name=" + name_label.text)
