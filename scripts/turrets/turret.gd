extends Node2D

export(float) var fire_interval := 2
export(float) var projectile_speed := 200
export(float) var projectile_radius := 6.0
export(float) var muzzle_offset := 32.0
export(float) var lead_bias := 0.0 # seconds to bias lead time (fine-tune)
export(float) var turn_rate := 8.0 # radians per second for smooth aiming
export(NodePath) var target_path
export(bool) var debug_logs := false

onready var _timer := 0.0
var _aim_dir: Vector2 = Vector2.RIGHT
var _aim_ready: bool = false

func _ready():
	set_process(true)

func _process(delta):
	_update_aim(delta)
	_timer += delta
	if _timer >= fire_interval:
		_timer = 0.0
		_fire()

func _fire():
	var tgt = _get_target()
	if tgt == null:
		return
	# Use cached aim direction for firing; compute if not ready
	if not _aim_ready:
		_update_aim(0.0)
	var p0: Vector2 = global_position
	var dir: Vector2 = _aim_dir
	_spawn_bullet(p0 + dir * muzzle_offset, dir)

func _pick_positive_root(a: float, b: float, c: float) -> float:
	# Solve a t^2 + b t + c = 0 for smallest positive t
	if abs(a) < 0.000001:
		if abs(b) < 0.000001:
			return -1.0
		var t: float = -c / b
		return t if t > 0.0 else -1.0
	var disc: float = b*b - 4.0*a*c
	if disc < 0.0:
		return -1.0
	var sqrt_disc: float = sqrt(disc)
	var t1: float = (-b - sqrt_disc) / (2.0 * a)
	var t2: float = (-b + sqrt_disc) / (2.0 * a)
	var tmin: float = 1e30
	if t1 > 0.0:
		tmin = min(tmin, t1)
	if t2 > 0.0:
		tmin = min(tmin, t2)
	return tmin if tmin < 1e29 else -1.0

func _get_target():
	if target_path != null and target_path != NodePath(""):
		var n = get_node_or_null(target_path)
		if n != null:
			return n
	# Try to find a node named 'player' in tree
	var root = get_tree().get_root()
	return root.find_node("player", true, false)

func _update_aim(delta: float) -> void:
	var tgt = _get_target()
	if tgt == null:
		_aim_ready = false
		return
	var p0: Vector2 = global_position
	var pt: Vector2 = tgt.global_position
	var vt: Vector2 = Vector2.ZERO
	if "velocity" in tgt:
		vt = tgt.velocity
	var s: float = max(1.0, projectile_speed)
	var r: Vector2 = pt - p0
	var a: float = vt.dot(vt) - s*s
	var b: float = 2.0 * r.dot(vt)
	var c: float = r.dot(r)
	var t: float = _pick_positive_root(a, b, c)
	if t < 0.0:
		t = 0.0
	var aim_point: Vector2 = pt + vt * (t + lead_bias)
	var desired_dir: Vector2 = (aim_point - p0).normalized()
	var desired_angle: float = desired_dir.angle()
	# Smooth rotation toward desired (instant on first init)
	if delta <= 0.0:
		rotation = desired_angle
	else:
		var step: float = clamp(turn_rate * delta, 0.0, 1.0)
		rotation = lerp_angle(rotation, desired_angle, step)
	_aim_dir = Vector2.RIGHT.rotated(rotation)
	_aim_ready = true
	if debug_logs and delta > 0.0:
		print("[turret] aim t=", String(t), " angle=", String(rotation))

func _spawn_bullet(origin: Vector2, dir: Vector2):
	var bullet = preload("res://scripts/turrets/bullet.gd").new()
	bullet.global_position = origin
	bullet.direction = dir
	bullet.speed = projectile_speed
	if "radius" in bullet:
		bullet.radius = projectile_radius
	# Prefer adding to the current scene so Canvas layering is consistent
	var root = get_tree().current_scene if get_tree().current_scene != null else get_tree().get_root()
	root.add_child(bullet)
