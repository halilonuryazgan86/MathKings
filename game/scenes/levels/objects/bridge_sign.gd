class_name BridgeSign
extends Area2D
## Kesir Köprüsü tabelası: suyun kıyısında; dokununca köprü bulmacası açılır.
## Orijin hücrenin alt ortasıdır.

signal reached

var built := false:
	set(value):
		built = value
		queue_redraw()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = Vector2(56, 128)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -64)
	add_child(cs)
	body_entered.connect(func(body: Node2D) -> void:
		if body is Player and not built:
			reached.emit())


func _draw() -> void:
	draw_rect(Rect2(-4, -96, 8, 96), Color("6b4a2b"))
	draw_rect(Rect2(-34, -112, 68, 40), Color("c58a4a"))
	draw_rect(Rect2(-34, -112, 68, 40), Color("6b4a2b"), false, 3.0)
	if built:
		draw_line(Vector2(-14, -92), Vector2(-4, -82), Color("2e7d32"), 5.0)
		draw_line(Vector2(-4, -82), Vector2(16, -104), Color("2e7d32"), 5.0)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(-30, -82), "1/2", HORIZONTAL_ALIGNMENT_CENTER, 60, 24, Color("3e2510"))
