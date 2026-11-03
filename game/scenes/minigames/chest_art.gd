class_name ChestArt
extends Control
## Hazine Avı sonundaki büyük sandık.

var opened := false:
	set(value):
		opened = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	if opened:
		draw_circle(size / 2.0, minf(size.x, size.y) * 0.45, Color(1, 0.9, 0.4, 0.3))
	TreasureChest.draw_chest(self, size / 2.0 + Vector2(0, 30), 3.0, opened)
