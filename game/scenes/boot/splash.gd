extends Control
## Açılış ekranı: kısa logo gösterimi, dokununca atlanır.

var _leaving := false


func _ready() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.3)
	tw.tween_callback(_leave)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.go_to(GameState.SCENE_MAIN_MENU)
