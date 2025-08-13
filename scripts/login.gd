extends Control

onready var name_label = $center/vbox/name_label
onready var signin_btn = $center/vbox/signin_btn
onready var signup_btn = $center/vbox/signup_btn
onready var logout_btn = $center/vbox/logout_btn
onready var back_btn = $center/vbox/back_btn

const MENU_SCENE := "res://scenes/menu.tscn"

func _ready():
	name_label.text = score_manager.get_player_name()
	_update_ui()
	signin_btn.connect("button_up", self, "_on_signin")
	signup_btn.connect("button_up", self, "_on_signup")
	logout_btn.connect("button_up", self, "_on_logout")
	back_btn.connect("button_up", self, "_on_back")

func _on_signin():
	var name = yield(_prompt("Enter username:"), "completed")
	name = str(name).strip_edges()
	if name == "":
		_show_message("Enter a username.")
		return
	# Ask for password (blank allowed for unsecured)
	var pwd = yield(_prompt_secret("Enter password (leave blank if unsecured):"), "completed")
	var rc = score_manager.signin(name, pwd)
	match rc:
		score_manager.LOGIN_OK:
			name_label.text = score_manager.get_player_name()
			_update_ui()
			_show_message("Signed in.")
		score_manager.LOGIN_WRONG_PASSWORD:
			_show_message("Wrong password.")
		score_manager.LOGIN_NOT_FOUND:
			_show_message("No such user. Use Sign up.")
		_:
			_show_message("Sign in failed.")

func _on_signup():
	var name = yield(_prompt("Create username:"), "completed")
	name = str(name).strip_edges()
	if name == "" or name == "Guest":
		_show_message("Enter a valid username (not Guest).")
		return
	var pwd = yield(_prompt_secret("Create password (leave blank to keep unsecured):"), "completed")
	var rc = score_manager.signup(name, pwd)
	match rc:
		score_manager.CREATE_OK:
			name_label.text = score_manager.get_player_name()
			_update_ui()
			_show_message("Account created.")
		score_manager.CREATE_EXISTS:
			_show_message("Name already exists. Sign in instead.")
		score_manager.CREATE_INVALID:
			_show_message("Invalid username.")
		_:
			_show_message("Sign up failed.")

func _on_logout():
	score_manager.logout()
	name_label.text = score_manager.get_player_name()
	_update_ui()
	_show_message("Signed out.")

func _on_back():
	get_tree().change_scene(MENU_SCENE)

func _update_ui():
	var signed_in = score_manager.is_signed_in()
	signin_btn.visible = not signed_in
	signup_btn.visible = not signed_in
	logout_btn.visible = true
	logout_btn.disabled = not signed_in

# --- dialogs ---

func _show_message(text: String):
	var dlg = AcceptDialog.new()
	dlg.dialog_text = text
	add_child(dlg)
	dlg.popup_centered()
	yield(dlg, "confirmed")
	dlg.queue_free()

func _prompt_secret(text: String) -> String:
	var dlg = AcceptDialog.new()
	dlg.dialog_text = text
	var le = LineEdit.new()
	le.rect_min_size = Vector2(260, 28)
	le.secret = true
	if dlg.has_method("get_content_area"):
		dlg.get_content_area().add_child(le)
	else:
		dlg.add_child(le)
	dlg.connect("about_to_show", le, "grab_focus")
	add_child(dlg)
	dlg.popup_centered()
	yield(dlg, "confirmed")
	var out = le.text
	dlg.queue_free()
	return out

func _prompt(text: String) -> String:
	var dlg = AcceptDialog.new()
	dlg.dialog_text = text
	var le = LineEdit.new()
	le.rect_min_size = Vector2(260, 28)
	if dlg.has_method("get_content_area"):
		dlg.get_content_area().add_child(le)
	else:
		dlg.add_child(le)
	dlg.connect("about_to_show", le, "grab_focus")
	add_child(dlg)
	dlg.popup_centered()
	yield(dlg, "confirmed")
	var out = le.text
	dlg.queue_free()
	return out
