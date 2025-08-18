extends KinematicBody2D
class_name Player

const DEG2RAD := PI / 180.0

# Tuning values (set per scene; ideal for inherited scenes with different sizes)
export(float) var move_speed : float = 400.0
export(float) var move_angle : float = 23.0
export(float) var velocity_lerp : float = 0.10
export(float) var rotation_lerp : float = 0.04

export(float) var fuel_max : float = 500.0
export(float) var fuel_drain_ground : float = 0.03
export(float) var fuel_drain_down : float = 0.04
export(float) var fuel_drain_up : float = 0.09
export(float) var fuel_drain_side : float = 0.07
export(float) var fuel_drain_hover : float = 0.05

export(float) var fall_speed_out_of_fuel : float = 3.0

onready var shape = $body_shape
onready var top_propeller = $top_prop
onready var back_propeller = $back_prop
onready var tween = $Tween

# State variables
var velocity : Vector2 = Vector2()
var fuel : float = 0.0
var out_of_fuel : bool = false
var crashed : bool = false

# Debug
export(bool) var debug_fuel := false
var _dbg_accum := 0.0

# Signals
signal remaining_fuel

func _ready():
	# Ensure physics/process are enabled
	set_physics_process(true)
	set_process(true)
	top_propeller.connect("body_entered", self, "_on_propeller_collide")
	back_propeller.connect("body_entered", self, "_on_propeller_collide")
	# Start with full fuel for this helicopter type
	fuel = fuel_max

func _physics_process(delta):
	var direction : Vector2 = Vector2(0, 0)

	if not crashed and not out_of_fuel and fuel > 0.0:
		if Input.is_action_pressed("move_right"):
			direction.x += 1
			direction.y -= 0.2
		if Input.is_action_pressed("move_left"):
			direction.x -= 1
			direction.y -= 0.2
		if Input.is_action_pressed("move_down"):
			direction.y += 1
		if Input.is_action_pressed("move_up"):
			direction.y -= 1
	else:
		# No control when crashed or out of fuel; fall down faster
		direction.y += fall_speed_out_of_fuel
	
	velocity.x = lerp(velocity.x, direction.x * move_speed, velocity_lerp)
	velocity.y = lerp(velocity.y, direction.y * move_speed, velocity_lerp)
	rotation = lerp_angle(rotation, direction.x * move_angle * DEG2RAD, rotation_lerp)
	var collision_info = move_and_collide(velocity * delta)
	
	# Fuel consumption: one place only
	if fuel > 0.0 and not crashed:
		if is_on_floor():
			# Sitting on ground
			fuel -= fuel_drain_ground
		elif direction.y > 0:
			# Moving down
			fuel -= fuel_drain_down
		elif direction.y < 0:
			# Moving up
			fuel -= fuel_drain_up
		elif direction.x != 0:
			# Moving sideways only
			fuel -= fuel_drain_side
		else:
			# Hovering
			fuel -= fuel_drain_hover

	if fuel <= 0.0 and not out_of_fuel:
		out_of_fuel = true
		fuel = 0.0
		if has_node("top_prop/sprite"): $top_prop/sprite.stop()
		if has_node("back_prop/sprite"): $back_prop/sprite.stop()
		if has_node("heli_audio"): $heli_audio.stop()
		call_deferred("_handle_out_of_fuel")
	
	emit_signal("remaining_fuel", clamp(fuel / max(fuel_max, 0.001), 0.0, 1.0))

	# Occasional debug to confirm emission cadence
	if debug_fuel:
		_dbg_accum += delta
		if _dbg_accum >= 0.5:
			_dbg_accum = 0.0
			print("[player] fuel=", String(fuel), "/", String(fuel_max))

func _on_propeller_collide(body):
	if crashed or body == self:
		return
	crashed = true
	if has_node("heli_audio"): $heli_audio.stop()
	if has_node("expl_audio"): $expl_audio.play()
	modulate = Color(0.7, 0.0, 0.0, 0.6)
	tween.interpolate_property(self, "modulate:a", 1, 0, 0.6, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	get_tree().change_scene("res://scenes/menu.tscn")

func _handle_out_of_fuel():
	yield(get_tree().create_timer(5), "timeout")
	if is_inside_tree():
		get_tree().change_scene("res://scenes/menu.tscn")

