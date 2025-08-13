extends Node

const PROFILE_PATH := "user://profile.cfg"
const SCORES_PATH := "user://scores.cfg"
const ACCOUNTS_PATH := "user://accounts.cfg"

var player_name := "Guest"
var _level_starts := {}
const LOGIN_OK := 0
const LOGIN_WRONG_PASSWORD := 1
const LOGIN_NEED_CLAIM_CONFIRM := 2
const LOGIN_INVALID := 3
const LOGIN_NOT_FOUND := 4
const CHANGE_OK := 0
const CHANGE_WRONG_OLD := 1
const CHANGE_FORBIDDEN := 2
const CREATE_OK := 0
const CREATE_EXISTS := 1
const CREATE_INVALID := 2

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

# --- AUTH / ACCOUNTS ---

func account_exists(name: String) -> bool:
	var accounts = _load_accounts()
	return accounts.has(name)

func signin(name: String, password: String) -> int:
	name = str(name).strip_edges()
	password = str(password)
	if name == "" or name == "Guest":
		player_name = "Guest"
		_save_profile()
		return LOGIN_OK
	var accounts = _load_accounts()
	if not accounts.has(name):
		return LOGIN_NOT_FOUND
	var entry = accounts[name]
	if typeof(entry) == TYPE_DICTIONARY and entry.has("hash") and entry.has("salt"):
		var ok = _verify_password(password, entry.get("salt", ""), entry.get("hash", ""))
		if ok:
			player_name = name
			_save_profile()
			return LOGIN_OK
		return LOGIN_WRONG_PASSWORD
	else:
		# unsecured account
		player_name = name
		_save_profile()
		return LOGIN_OK

func login(name: String, password: String, confirm_claim := false) -> int:
	name = str(name).strip_edges()
	password = str(password)
	if name == "" or name == "Guest":
		player_name = "Guest"
		_save_profile()
		return LOGIN_OK
	var accounts = _load_accounts()
	if accounts.has(name):
		var entry = accounts[name]
		if typeof(entry) == TYPE_DICTIONARY and entry.has("hash") and entry.has("salt"):
			# Secured account: require correct password
			var ok = _verify_password(password, entry.get("salt", ""), entry.get("hash", ""))
			if ok:
				player_name = name
				_save_profile()
				return LOGIN_OK
			return LOGIN_WRONG_PASSWORD
		else:
			# Unsecured account (blank password)
			if password.strip_edges() == "":
				player_name = name
				_save_profile()
				return LOGIN_OK
			# Wants to claim with a password
			if not confirm_claim:
				return LOGIN_NEED_CLAIM_CONFIRM
			_set_account_password(accounts, name, password)
			_save_accounts(accounts)
			player_name = name
			_save_profile()
			return LOGIN_OK
	else:
		# Account does not exist yet: for explicit signin use LOGIN_NOT_FOUND
		return LOGIN_NOT_FOUND

func signup(name: String, password: String) -> int:
	name = str(name).strip_edges()
	password = str(password)
	if name == "" or name == "Guest":
		return CREATE_INVALID
	var accounts = _load_accounts()
	if accounts.has(name):
		return CREATE_EXISTS
	if password.strip_edges() == "":
		# create unsecured entry
		accounts[name] = {}
	else:
		_set_account_password(accounts, name, password)
	_save_accounts(accounts)
	player_name = name
	_save_profile()
	return CREATE_OK

func logout():
	player_name = "Guest"
	_save_profile()

func change_password(old_password: String, new_password: String) -> int:
	var name = player_name
	if name == null or name == "" or name == "Guest":
		return CHANGE_FORBIDDEN
	var accounts = _load_accounts()
	var entry = accounts.get(name, null)
	if typeof(entry) == TYPE_DICTIONARY and entry.has("hash") and entry.has("salt"):
		# Secured: verify old
		var ok = _verify_password(old_password, entry.get("salt", ""), entry.get("hash", ""))
		if not ok:
			return CHANGE_WRONG_OLD
		_set_account_password(accounts, name, new_password)
		_save_accounts(accounts)
		return CHANGE_OK
	else:
		# Unsecured: allow set without old (old may be blank)
		_set_account_password(accounts, name, new_password)
		_save_accounts(accounts)
		return CHANGE_OK

func is_account_secured(name: String) -> bool:
	var accounts = _load_accounts()
	if accounts.has(name):
		var entry = accounts[name]
		return typeof(entry) == TYPE_DICTIONARY and entry.has("hash") and entry.has("salt")
	return false

func _set_account_password(accounts: Dictionary, name: String, password: String) -> void:
	var salt = _gen_salt()
	var h = _hash_password(password, salt)
	accounts[name] = {"salt": salt, "hash": h}

func _gen_salt() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var bytes = PoolByteArray()
	for i in range(16):
		bytes.append(int(rng.randi() % 256))
	return Marshalls.raw_to_base64(bytes)

func _hash_password(password: String, salt: String) -> String:
	var hc = HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(Marshalls.base64_to_raw(salt))
	hc.update(password.to_utf8())
	var digest: PoolByteArray = hc.finish()
	return Marshalls.raw_to_base64(digest)

func _verify_password(password: String, salt: String, expected_hash: String) -> bool:
	return _hash_password(password, salt) == str(expected_hash)

func _load_accounts() -> Dictionary:
	var cf = ConfigFile.new()
	var err = cf.load(ACCOUNTS_PATH)
	var json_text = "{}"
	if err == OK:
		json_text = str(cf.get_value("accounts", "data", "{}"))
	var parsed = JSON.parse(json_text)
	if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
		return parsed.result
	return {}

func _save_accounts(data: Dictionary) -> void:
	var cf = ConfigFile.new()
	cf.set_value("accounts", "data", to_json(data))
	cf.save(ACCOUNTS_PATH)

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
