extends Control

const EMPTY_ANGLE : float = -PI / 3.0

onready var needle = $needle
export(bool) var debug_logs := false

# Smooth animation toward target angle even if updates are bursty
export(float) var follow_speed := 8.0 # larger = snappier
var _target_angle := -EMPTY_ANGLE # start as full by default

func _ready():
	set_process(true)
	# Fallback: try to auto-connect to a Player if the level hasn't yet
	call_deferred("_auto_connect")

func _auto_connect():
	if get_tree() == null:
		return
	var root = get_tree().get_root()
	if root == null:
		return
	var p = root.find_node("player", true, false)
	if p != null and p.has_signal("remaining_fuel"):
		if not p.is_connected("remaining_fuel", self, "_on_fuel_update"):
			p.connect("remaining_fuel", self, "_on_fuel_update")
		# Initialize to current fuel if properties exist
		var fmax := 1.0
		var fval := 1.0
		if "fuel_max" in p:
			fmax = max(0.001, float(p.fuel_max))
		if "fuel" in p:
			fval = clamp(float(p.fuel), 0.0, fmax)
		_on_fuel_update(fval / fmax)

func _on_fuel_update(percentage : float):
	# Guard against invalid values
	var pct := clamp(percentage, 0.0, 1.0)
	var rot := lerp_angle(EMPTY_ANGLE, -EMPTY_ANGLE, pct)
	_target_angle = rot
	# Snap immediately as well so first update reflects instantly
	needle.rotation = rot
	if debug_logs:
		print("[gauge] pct=", String(pct), " rot=", String(rot))

	# Play a warning beep when low on fuel; stop otherwise
	if pct > 0.0 and pct < 0.15:
		if not $warning_audio.playing:
			$warning_audio.play()
	else:
		if $warning_audio.playing:
			$warning_audio.stop()

func _process(delta):
	# Continuously approach target angle for smoother and consistent motion
	if is_instance_valid(needle):
		var t := clamp(delta * follow_speed, 0.0, 1.0)
		needle.rotation = lerp_angle(needle.rotation, _target_angle, t)
