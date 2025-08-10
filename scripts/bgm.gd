extends Node

onready var bgm_player : AudioStreamPlayer = AudioStreamPlayer.new()
onready var stream : AudioStreamOGGVorbis = preload("res://assets/sfx/RevvedUp.ogg")

func _ready():
	var root = get_tree().get_root()
	# Avoid creating multiple music players across scene changes
	if root.has_node("BGM_Player"):
		queue_free()
		return

	bgm_player.name = "BGM_Player"
	bgm_player.pause_mode = Node.PAUSE_MODE_PROCESS
	bgm_player.volume_db = -14.5
	bgm_player.stream = stream
	root.call_deferred("add_child", bgm_player)
	# Defer play to ensure it's added to the tree
	call_deferred("_start_playing")

func _start_playing():
	if is_instance_valid(bgm_player) and not bgm_player.playing:
		bgm_player.play()
