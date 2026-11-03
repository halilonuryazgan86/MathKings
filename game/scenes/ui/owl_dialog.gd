class_name OwlDialog
extends CanvasLayer
## Bilge Baykuş konuşma balonu. Açıkken oyun duraklar. Sprint 2'de ipuçları için de kullanılacak.

signal finished

var _lines := PackedStringArray()
var _index := 0
var _was_paused := false

@onready var _root: Control = $Root
@onready var _text: Label = %Text
@onready var _next: Button = %NextButton
@onready var _skip: Button = %SkipButton


func _ready() -> void:
	_root.hide()
	_next.pressed.connect(_advance)
	_skip.pressed.connect(_close)


func is_open() -> bool:
	return _root.visible


func show_lines(lines: PackedStringArray) -> void:
	if lines.is_empty():
		finished.emit()
		return
	_lines = lines
	_index = 0
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root.show()
	_show_current()
	_next.grab_focus()


func _show_current() -> void:
	_text.text = _lines[_index]
	_text.visible_ratio = 0.0
	create_tween().tween_property(_text, "visible_ratio", 1.0, 0.025 * _text.text.length())


func _advance() -> void:
	if _text.visible_ratio < 1.0:
		_text.visible_ratio = 1.0  # İlk dokunuş metni tamamlar.
		return
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_current()


func _close() -> void:
	_root.hide()
	get_tree().paused = _was_paused
	finished.emit()
