extends Area2D

signal person_saved

# Optional: drag textures here in the editor to define the pool explicitly.
export(Array, Texture) var texture_variants = []
# Auto-scan fallback: look in this folder for textures whose filenames start with the prefix below.
export(String) var variants_dir = "res://assets/sprites/persons"
export(String) var filename_prefix = "person"

func _ready():
	randomize()
	_randomize_sprite()
	connect("body_entered", self, "_on_body_entered")

func _on_body_entered(body):
	if body is Player:
		emit_signal("person_saved")
		queue_free()

func _randomize_sprite():
	var sprite = get_node_or_null("Sprite")
	if sprite == null:
		return

	var chosen = null
	if texture_variants != null and texture_variants.size() > 0:
		chosen = texture_variants[randi() % texture_variants.size()]
	else:
		var files = _scan_for_textures()
		if files.size() > 0:
			var path = files[randi() % files.size()]
			if ResourceLoader.exists(path):
				chosen = load(path)

	if chosen != null and chosen is Texture:
		sprite.texture = chosen

func _scan_for_textures():
	var results = []
	var d = Directory.new()
	if d.open(variants_dir) != OK:
		return results
	d.list_dir_begin(true, true)
	var n = d.get_next()
	while n != "":
		if not d.current_is_dir():
			if n.begins_with(filename_prefix) and _is_texture_file(n):
				results.append(variants_dir + "/" + n)
		n = d.get_next()
	d.list_dir_end()
	return results

func _is_texture_file(name):
	var low = String(name).to_lower()
	return low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg") or low.ends_with(".webp") or low.ends_with(".svg")
