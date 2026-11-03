class_name Hazard
extends Area2D
## Dikenli çalı. Dokunan oyuncu son kontrol noktasından devam eder (ceza yok).
## Orijin hücrenin alt ortasıdır.

signal touched


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = Vector2(52, 22)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -11)
	add_child(cs)
	body_entered.connect(func(body: Node2D) -> void:
		if body is Player:
			touched.emit())


func _draw() -> void:
	draw_rect(Rect2(-32, -10, 64, 10), Color("3d6b2a"))
	for i in 4:
		var x := -32.0 + i * 16.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, -8), Vector2(x + 8, -30), Vector2(x + 16, -8)]), Color("7a4a8c"))
