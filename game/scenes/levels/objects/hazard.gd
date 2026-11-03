class_name Hazard
extends Area2D
## Tehlike: dikenli çalı ("thorns") veya su ("water"). Dokunan oyuncu son kontrol
## noktasından devam eder (ceza yok). Orijin hücrenin alt ortasıdır.

signal touched

var style := "thorns"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = Vector2(52, 22) if style == "thorns" else Vector2(64, 40)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -shape.size.y / 2.0)
	add_child(cs)
	body_entered.connect(func(body: Node2D) -> void:
		if body is Player:
			touched.emit())


func _draw() -> void:  # Statik çizim: her kare yeniden çizilmez (performans).
	if style == "water":
		draw_rect(Rect2(-32, -48, 64, 48), Color(0.16, 0.6, 0.85, 0.85))
		draw_arc(Vector2(-16, -48), 12, PI + 0.4, TAU - 0.4, 8, Color(1, 1, 1, 0.6), 3.0)
		draw_arc(Vector2(16, -46), 12, PI + 0.4, TAU - 0.4, 8, Color(1, 1, 1, 0.6), 3.0)
		return
	draw_rect(Rect2(-32, -10, 64, 10), Color("3d6b2a"))
	for i in 4:
		var x := -32.0 + i * 16.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, -8), Vector2(x + 8, -30), Vector2(x + 16, -8)]), Color("7a4a8c"))
