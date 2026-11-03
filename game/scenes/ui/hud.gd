class_name Hud
extends CanvasLayer
## Bölüm içi arayüz: altın/yıldız sayacı, duraklatma menüsü, bölüm sonu ekranı.

@onready var _gold_label: Label = %GoldLabel
@onready var _stars_label: Label = %StarsLabel
@onready var _pause_button: Button = %PauseButton
@onready var _pause_menu: Control = %PauseMenu
@onready var _resume_button: Button = %ResumeButton
@onready var _music_button: Button = %MusicButton
@onready var _sfx_button: Button = %SfxButton
@onready var _result_menu: Control = %ResultMenu
@onready var _result_gold: Label = %ResultGold
@onready var _result_stars: Label = %ResultStars
@onready var _replay_button: Button = %ReplayButton


func _ready() -> void:
	_pause_menu.hide()
	_result_menu.hide()
	_pause_button.pressed.connect(open_pause)
	_resume_button.pressed.connect(close_pause)
	_music_button.pressed.connect(func() -> void:
		Settings.set_music(not Settings.music_on)
		_refresh_audio_labels())
	_sfx_button.pressed.connect(func() -> void:
		Settings.set_sfx(not Settings.sfx_on)
		_refresh_audio_labels())
	%MenuButton.pressed.connect(_to_main_menu)
	%ResultMenuButton.pressed.connect(_to_main_menu)
	_replay_button.pressed.connect(func() -> void: GameState.start_level(GameState.current_level_id))
	GameState.gold_changed.connect(set_gold)
	set_gold(GameState.save.gold())
	_refresh_audio_labels()


func set_gold(total: int) -> void:
	_gold_label.text = str(total)


func set_stars(collected: int, total: int) -> void:
	_stars_label.text = "%d / %d" % [collected, total]


func open_pause() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	_pause_button.hide()
	_pause_menu.show()
	_resume_button.grab_focus()


func close_pause() -> void:
	_pause_menu.hide()
	_pause_button.show()
	get_tree().paused = false


func show_result(gold_gained: int, stars: int, total_stars: int) -> void:
	_pause_button.hide()
	_result_gold.text = tr("RESULT_GOLD").format({"gold": gold_gained})
	_result_stars.text = tr("RESULT_STARS").format({"stars": stars, "total": total_stars})
	_result_menu.show()
	_replay_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _pause_menu.visible:
		close_pause()
	elif not _result_menu.visible:
		open_pause()
	get_viewport().set_input_as_handled()


func _to_main_menu() -> void:
	GameState.go_to(GameState.SCENE_MAIN_MENU)


func _refresh_audio_labels() -> void:
	_music_button.text = tr("PAUSE_MUSIC_ON" if Settings.music_on else "PAUSE_MUSIC_OFF")
	_sfx_button.text = tr("PAUSE_SFX_ON" if Settings.sfx_on else "PAUSE_SFX_OFF")
