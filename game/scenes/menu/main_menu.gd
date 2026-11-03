extends Control
## Ana menü: misafir oyun, (Sprint 3'e kadar devre dışı) giriş/kayıt.

@onready var _guest_button: Button = %GuestButton
@onready var _change_hero_button: Button = %ChangeHeroButton
@onready var _notice: Label = %Notice
var _notice_tween: Tween


func _ready() -> void:
	var has_profile := GameState.save.has_profile()
	_guest_button.text = "MENU_CONTINUE" if has_profile else "MENU_GUEST"
	_change_hero_button.visible = has_profile
	_notice.modulate.a = 0.0
	_guest_button.pressed.connect(_on_guest_pressed)
	_change_hero_button.pressed.connect(func() -> void: GameState.go_to(GameState.SCENE_CHARACTER_SELECT))
	%LoginButton.pressed.connect(_show_coming_soon)
	%RegisterButton.pressed.connect(_show_coming_soon)
	_guest_button.grab_focus()


func _on_guest_pressed() -> void:
	if GameState.save.has_profile():
		GameState.start_level(GameState.FIRST_LEVEL_ID)
	else:
		GameState.go_to(GameState.SCENE_PROFILE_SETUP)


func _show_coming_soon() -> void:
	if _notice_tween:
		_notice_tween.kill()
	_notice.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(2.0)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
