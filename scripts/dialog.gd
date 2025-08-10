extends Control

var lines = []
var current_line = 0

func _ready():
	set_process_input(true)
	# Ensure label exists and initialize safely
	if has_node("label") and lines.size() > 0:
		$label.text = str(lines[0])
	# Also listen for GUI input to support clicks
	connect("gui_input", self, "_on_dialog_event")

func _input(event):
	_on_dialog_event(event)

func _on_dialog_event(ev):
	# Advance only on release of mouse click or Enter/Space release
	var is_release : bool = ((ev is InputEventMouseButton) or (ev is InputEventKey)) and (not ev.pressed)
	if not is_release:
		return

	if lines.size() == 0:
		get_tree().paused = false
		queue_free()
		return

	if current_line < lines.size() - 1:
		current_line += 1
		if has_node("label"):
			$label.text = str(lines[current_line])
	else:
		get_tree().paused = false
		queue_free()

func set_lines(string_array):
	if string_array == null:
		lines = []
	else:
		lines = string_array
	current_line = 0
	if has_node("label") and lines.size() > 0:
		$label.text = str(lines[current_line])
