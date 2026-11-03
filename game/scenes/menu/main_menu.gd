extends Control
## Ana menü: misafir oyun, yetişkin hesabı (ebeveyn kapısı ardından) ve profil seçimi.

@onready var _guest_button: Button = %GuestButton
@onready var _change_hero_button: Button = %ChangeHeroButton
@onready var _login_button: Button = %LoginButton
@onready var _register_button: Button = %RegisterButton
@onready var _player: Label = %PlayerLabel
@onready var _notice: Label = %Notice


func _ready() -> void:
	var save := GameState.save
	var has_profile := save.has_profile()
	_guest_button.text = "MENU_CONTINUE" if has_profile else "MENU_GUEST"
	_change_hero_button.visible = has_profile
	_player.text = tr("MENU_PLAYER_CLOUD" if GameState.is_cloud_profile() else "MENU_PLAYER_GUEST") \
		.format({"name": save.nickname()}) if has_profile else ""

	var logged_in := Cloud.is_logged_in()
	_login_button.text = "MENU_PROFILES" if logged_in else "MENU_LOGIN"
	_register_button.visible = not logged_in

	_guest_button.pressed.connect(_on_guest_pressed)
	_change_hero_button.pressed.connect(func() -> void: GameState.go_to(GameState.SCENE_CHARACTER_SELECT))
	_login_button.pressed.connect(func() -> void:
		_through_gate(GameState.SCENE_PROFILE_PICKER if Cloud.is_logged_in() else GameState.SCENE_ACCOUNT, "login"))
	_register_button.pressed.connect(func() -> void: _through_gate(GameState.SCENE_ACCOUNT, "register"))
	_guest_button.grab_focus()

	_notice.modulate.a = 0.0
	if not GameState.notice_key.is_empty():
		_show_notice(tr(GameState.notice_key))
		GameState.notice_key = ""


func _on_guest_pressed() -> void:
	if GameState.save.has_profile():
		GameState.start_level(GameState.FIRST_LEVEL_ID)
	else:
		GameState.creating_cloud_profile = false
		GameState.go_to(GameState.SCENE_PROFILE_SETUP)


## Hesap işlemleri yetişkinler içindir: önce ebeveyn kapısı.
func _through_gate(target_scene: String, mode: String) -> void:
	GameState.after_gate_scene = target_scene
	GameState.account_mode = mode
	GameState.go_to(GameState.SCENE_PARENTAL_GATE)


func _show_notice(text: String) -> void:
	_notice.text = text
	_notice.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(_notice, "modulate:a", 0.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
