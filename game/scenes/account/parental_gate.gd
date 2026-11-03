extends Control
## Ebeveyn kapısı: tarafsız yaş sorusu (doğum yılı). Girilen yıl hiçbir yere kaydedilmez.
## 18 yaş altı yanıtta kapı birkaç dakika kilitlenir (deneme-yanılmayı zorlaştırmak için).

const ADULT_AGE := 18
const LOCK_SECONDS := 300

static var _locked_until := 0.0

@onready var _year: LineEdit = %YearEdit
@onready var _status: Label = %Status
@onready var _continue: Button = %ContinueButton


func _ready() -> void:
	_year.text_submitted.connect(func(_t: String) -> void: _check())
	_continue.pressed.connect(_check)
	%BackButton.pressed.connect(_back)
	if _is_locked():
		_show_locked()
	else:
		_year.grab_focus()


func _check() -> void:
	if _is_locked():
		_show_locked()
		return
	var text := _year.text.strip_edges()
	var current_year: int = Time.get_date_dict_from_system().year
	if not text.is_valid_int() or int(text) < 1900 or int(text) > current_year:
		_status.text = tr("GATE_INVALID")
		return
	if current_year - int(text) < ADULT_AGE:
		_locked_until = Time.get_unix_time_from_system() + LOCK_SECONDS
		_show_locked()
		return
	GameState.go_to(GameState.after_gate_scene)


func _is_locked() -> bool:
	return Time.get_unix_time_from_system() < _locked_until


func _show_locked() -> void:
	_status.text = tr("GATE_CHILD")
	_year.editable = false
	_continue.disabled = true


func _back() -> void:
	GameState.go_to(GameState.SCENE_MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
