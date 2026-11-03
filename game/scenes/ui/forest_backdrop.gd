extends Control
## Geçici, kodla çizilen orman arka planı (menüler ve bölüm arka planı).


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s := size
	var steps := 24
	for i in steps:
		var t := float(i) / steps
		draw_rect(Rect2(0, s.y * t, s.x, s.y / steps + 1.0), Color("4fb3e8").lerp(Color("c4ecff"), t))
	draw_circle(Vector2(s.x * 0.84, s.y * 0.17), s.y * 0.08, Color("fff3a3"))
	_hills(s.y * 0.62, 30.0, 0.006, 0.0, Color("8fd07a"))
	_trees(s.y * 0.66, 0.75, Color("4f9d4a"))
	_hills(s.y * 0.78, 22.0, 0.009, 1.7, Color("5fb052"))
	_trees(s.y * 0.82, 1.0, Color("2f7a3a"))


func _hills(base_y: float, amp: float, freq: float, phase: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var x := size.x * i / n
		pts.append(Vector2(x, base_y + sin(x * freq + phase) * amp))
	pts.append(Vector2(size.x, size.y))
	pts.append(Vector2(0, size.y))
	draw_colored_polygon(pts, color)


func _trees(base_y: float, scale_f: float, color: Color) -> void:
	var spacing := 170.0 * scale_f
	var count := int(size.x / spacing) + 2
	for i in count:
		var x := i * spacing + fmod(i * 53.0, 60.0)
		var h := (90.0 + fmod(i * 37.0, 50.0)) * scale_f
		draw_rect(Rect2(x - 7 * scale_f, base_y - h * 0.4, 14 * scale_f, h * 0.4 + 40), Color("6b4a2b"))
		draw_circle(Vector2(x, base_y - h * 0.55), h * 0.35, color)
		draw_circle(Vector2(x - h * 0.2, base_y - h * 0.4), h * 0.25, color)
		draw_circle(Vector2(x + h * 0.2, base_y - h * 0.4), h * 0.25, color)
