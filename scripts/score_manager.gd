extends Node

const PROFILE_PATH := "user://profile.cfg"
const SCORES_PATH := "user://scores.cfg"

var player_name := "Guest"
var _level_starts := {}

func _ready():
	_load_profile()

func is_signed_in():
	return player_name != null and player_name.strip_edges() != "" and player_name != "Guest"

func set_player_name(name: String):
	player_name = name.strip_edges()
	if player_name == "":
		player_name = "Guest"
	_save_profile()

func get_player_name():
	return player_name

func start_level(level_id: String):
	_level_starts[level_id] = OS.get_ticks_msec()

func finish_level(level_id: String) -> float:
	if not _level_starts.has(level_id):
		return -1.0
	var start = _level_starts[level_id]
	_level_starts.erase(level_id)
	var ms = OS.get_ticks_msec() - int(start)
	return float(ms) / 1000.0

func submit_time(level_id: String, seconds: float):
	var data = _load_scores()
	if not data.has(level_id):
		data[level_id] = []
	var entries = data[level_id]
	var entry = {
		"name": player_name,
		"time": seconds,
		"ts": OS.get_unix_time()
	}
	entries.append(entry)
	# sort ascending by time
	entries.sort_custom(self, "_cmp_time")
	# keep top 10
	if entries.size() > 10:
		entries.resize(10)
	data[level_id] = entries
	_save_scores(data)

func get_leaderboard(level_id: String) -> Array:
	var data = _load_scores()
	if data.has(level_id):
		return data[level_id]
	return []

func _cmp_time(a, b):
	var ta = 999999.0
	if typeof(a) == TYPE_DICTIONARY and a.has("time"):
		ta = float(a["time"])
	var tb = 999999.0
	if typeof(b) == TYPE_DICTIONARY and b.has("time"):
		tb = float(b["time"])
	if ta == tb:
		return false
	return ta < tb

func _load_profile():
	var cf = ConfigFile.new()
	var err = cf.load(PROFILE_PATH)
	if err == OK:
		player_name = str(cf.get_value("profile", "name", "Guest"))
	else:
		player_name = "Guest"

func _save_profile():
	var cf = ConfigFile.new()
	cf.set_value("profile", "name", player_name)
	cf.save(PROFILE_PATH)

func _load_scores() -> Dictionary:
	var cf = ConfigFile.new()
	var err = cf.load(SCORES_PATH)
	var json_text = "{}"
	if err == OK:
		json_text = str(cf.get_value("scores", "data", "{}"))
	var result = JSON.parse(json_text)
	if result.error == OK and typeof(result.result) == TYPE_DICTIONARY:
		return result.result
	return {}

func _save_scores(data: Dictionary):
	var cf = ConfigFile.new()
	cf.set_value("scores", "data", to_json(data))
	cf.save(SCORES_PATH)
