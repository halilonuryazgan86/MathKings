class_name QuizOverlay
extends CanvasLayer
## Mini oyunların ortak soru akışı. Açıkken oyun dünyası duraklar.
## Yanlışta seçenek elenir ve ipucu gösterilir; ikinci yanlışta çözüm gösterilir. Ceza yoktur.
## Sahnede gereken düğümler: Root, %HintPanel, %HintLabel, %ContinueButton.

signal finished(result: bool)

const CORRECT_TINT := Color(0.6, 1.0, 0.6)
const WRONG_TINT := Color(0.7, 0.7, 0.7, 0.6)
const MAX_ATTEMPTS := 2

var _q: MathQuestion
var _attempts := 0
var _busy := false
var _buttons: Array[Button] = []

@onready var _root: Control = $Root
@onready var _hint_panel: Control = %HintPanel
@onready var _hint: Label = %HintLabel
@onready var _continue: Button = %ContinueButton


func _ready() -> void:
	_root.hide()
	_continue.pressed.connect(func() -> void:
		_continue.hide()
		_revealed())


func is_open() -> bool:
	return _root.visible


## Alt sınıflar: doğru cevaptan sonra (await edilebilir).
func _correct(_button: Button) -> void:
	pass


## Alt sınıflar: çözüm gösterilip "Devam"a basıldıktan sonra.
func _revealed() -> void:
	pass


func _open() -> void:
	get_tree().paused = true
	_root.show()


func _close(result: bool) -> void:
	_root.hide()
	get_tree().paused = false
	finished.emit(result)


func _make_buttons(container: Container, count: int, min_size: Vector2, font_size: int) -> void:
	for i in count:
		var b := Button.new()
		b.custom_minimum_size = min_size
		b.add_theme_font_size_override("font_size", font_size)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_choice.bind(b))
		container.add_child(b)
		_buttons.append(b)


func _ask(q: MathQuestion, values: Array) -> void:
	_q = q
	_attempts = 0
	_continue.hide()
	for i in _buttons.size():
		var b := _buttons[i]
		b.text = str(values[i])
		b.set_meta("value", values[i])
		b.disabled = false
		b.modulate = Color.WHITE
	_busy = false


func _on_choice(button: Button) -> void:
	if _busy:
		return
	if _q.is_correct(button.get_meta("value")):
		_busy = true
		GameState.save.record_answer(_q.topic, _attempts == 0)
		for b in _buttons:
			b.disabled = b != button
		button.modulate = CORRECT_TINT
		_hint_panel.hide()
		Sfx.play(self, "correct")
		_correct(button)
		return
	_attempts += 1
	Sfx.play(self, "wrong")
	if _attempts < MAX_ATTEMPTS:
		button.disabled = true
		button.modulate = WRONG_TINT
		_show_hint(tr("BATTLE_ALMOST") + " " + _q.hint_text())
		return
	_busy = true
	GameState.save.record_answer(_q.topic, false)
	for b in _buttons:
		var is_answer := _q.is_correct(b.get_meta("value"))
		b.disabled = not is_answer
		b.modulate = CORRECT_TINT if is_answer else WRONG_TINT
	_show_hint(_q.solution_text())
	_continue.show()


func _show_hint(text: String) -> void:
	_hint.text = text
	_hint_panel.show()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
