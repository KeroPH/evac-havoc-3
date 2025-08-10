extends Node2D

export(float) var spawn_interval_min := 2.5
export(float) var spawn_interval_max := 5.0
export(float) var speed_min := 120.0
export(float) var speed_max := 220.0
export(bool) var spawn_both_directions := true
export(bool) var debug_logs := false

const HELI_DIR := "res://scenes/helicopters"

var _timer := 0.0
var _next := 0.0

func _ready():
	randomize()
	_reset_timer()

func d(msg):
	if debug_logs:
		print("[menu-helis] ", msg)

func _process(delta):
	_timer += delta
	if _timer >= _next:
		_spawn()
		_reset_timer()

func _reset_timer():
	_timer = 0.0
	_next = rand_range(spawn_interval_min, spawn_interval_max)

func _spawn():
	var options = _find_helicopters()
	if options.size() == 0:
		return
	var path = options[randi() % options.size()]
	if not ResourceLoader.exists(path):
		return
	var scene = load(path)
	var heli = scene.instance()
	# Visual-only: disable processing from player script if present
	if heli.has_method("set_physics_process"):
		heli.set_physics_process(false)
	if heli.has_method("set_process"):
		heli.set_process(false)
	# Ensure no cameras from the heli become active
	_neutralize_cameras(heli)
	# Place off-screen and move across
	var view = get_viewport_rect().size
	var y = rand_range(view.y * 0.15, view.y * 0.75)
	var dir = 1
	if spawn_both_directions and randi() % 2 == 0:
		dir = -1
	var start_x = -200
	var end_x = view.x + 200
	if dir != 1:
		start_x = view.x + 200
		end_x = -200
	heli.position = Vector2(start_x, y)
	add_child(heli)
	# Double-safety: turn off any Camera2D that might have set current=true on enter-tree
	call_deferred("_neutralize_cameras", heli)
	# Tween across and free
	var t = Tween.new()
	add_child(t)
	var speed = rand_range(speed_min, speed_max)
	var duration = abs(end_x - start_x) / max(1.0, speed)
	t.interpolate_property(heli, "position", heli.position, Vector2(end_x, y), duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	t.start()
	t.connect("tween_all_completed", self, "_on_tween_done", [heli, t])
	# Orient sprite if needed
	if heli is Node2D:
		# Ensure no residual rotation or vertical flip from source scene
		heli.rotation = 0
		heli.scale.y = abs(heli.scale.y)
		if dir == -1:
			heli.scale.x = -abs(heli.scale.x)
		else:
			heli.scale.x = abs(heli.scale.x)

func _on_tween_done(heli, tween):
	if is_instance_valid(heli):
		heli.queue_free()
	if is_instance_valid(tween):
		tween.queue_free()

func _neutralize_cameras(node):
	# Recursively set any Camera2D.current = false so they don't hijack the menu view
	if node is Camera2D:
		node.current = false
		return
	if node is Node:
		for c in node.get_children():
			_neutralize_cameras(c)

func _find_helicopters():
	var results = []
	var d = Directory.new()
	if d.open(HELI_DIR) != OK:
		return results
	d.list_dir_begin(true, true)
	var n = d.get_next()
	while n != "":
		if not d.current_is_dir() and n.ends_with(".tscn"):
			results.append(HELI_DIR + "/" + n)
		n = d.get_next()
	d.list_dir_end()
	return results
