extends Control
## Bilge Baykuş'un geçici, kodla çizilen portresi.


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.42
	draw_set_transform(c + Vector2(0, r * 0.15), 0.0, Vector2(1.0, 1.12))
	draw_circle(Vector2.ZERO, r, Color("8a5a35"))
	draw_circle(Vector2(0, r * 0.35), r * 0.6, Color("d9b38c"))
	draw_set_transform(Vector2.ZERO)
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * r * 0.42, -r * 0.1)
		draw_circle(e, r * 0.34, Color.WHITE)
		draw_circle(e, r * 0.34, Color("5a3a20"), false, 3.0)
		draw_circle(e + Vector2(0, r * 0.04), r * 0.15, Color("2b2118"))
		draw_circle(e + Vector2(r * 0.05, -r * 0.03), r * 0.05, Color.WHITE)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.12, r * 0.22), c + Vector2(r * 0.12, r * 0.22), c + Vector2(0, r * 0.45)]),
		Color("f2a63b"))
	# Bilgelik şapkası
	var top := c + Vector2(0, -r * 0.92)
	draw_colored_polygon(PackedVector2Array([
		top + Vector2(-r * 0.75, 0), top + Vector2(0, -r * 0.28),
		top + Vector2(r * 0.75, 0), top + Vector2(0, r * 0.28)]), Color("2c3e66"))
	draw_line(top, top + Vector2(r * 0.6, r * 0.35), Color("ffd54a"), 3.0)
	draw_circle(top + Vector2(r * 0.6, r * 0.38), r * 0.07, Color("ffd54a"))
