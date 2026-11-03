class_name HpBar
extends Control
## Canavarın canı: kristal parçaları. Her doğru cevap bir parçayı söndürür.

var max_value := 5:
	set(v):
		max_value = v
		queue_redraw()
var value := 5:
	set(v):
		value = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := minf(size.y * 0.42, size.x / (max_value * 2.4))
	var gap := r * 2.4
	var start_x := size.x - gap * max_value + gap / 2.0
	for i in max_value:
		var c := Vector2(start_x + i * gap, size.y / 2.0)
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)])
		var full := i < value
		draw_colored_polygon(pts, Color("b18cff") if full else Color(1, 1, 1, 0.25))
		pts.append(pts[0])
		draw_polyline(pts, Color("4b2fa8") if full else Color(1, 1, 1, 0.5), 3.0)
