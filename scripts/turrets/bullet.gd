extends Area2D

export(float) var speed := .0005
export(float) var lifetime := 5.0
export(Vector2) var direction := Vector2.RIGHT
export(float) var radius := 4.0
export(Color) var color := Color(1, 0.2, 0.2)

onready var _vel := Vector2.ZERO
onready var _time := 0.0

func _ready():
	set_process(true)
	z_index = 1000
	_vel = direction.normalized() * speed
	# Ensure a collision shape exists and matches visual radius
	var col: CollisionShape2D = null
	for c in get_children():
		if c is CollisionShape2D:
			col = c
			break
	if col == null:
		col = CollisionShape2D.new()
		add_child(col)
	var circle := col.shape if col.shape != null and col.shape is CircleShape2D else CircleShape2D.new()
	circle.radius = radius
	col.shape = circle
	# Connect collision
	if not is_connected("body_entered", self, "_on_hit"):
		connect("body_entered", self, "_on_hit")

func _process(delta):
	_time += delta
	if _time >= lifetime:
		queue_free()
		return
	global_position += _vel * delta
	update() # redraw for visibility

func _draw():
	draw_circle(Vector2.ZERO, radius, color)

func _on_hit(body):
	if body is Player:
		body.crash()
		queue_free()
