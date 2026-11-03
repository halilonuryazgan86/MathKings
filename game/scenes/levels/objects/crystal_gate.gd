class_name CrystalGate
extends Area2D
## Bölüm sonu Kristal Kapısı. Sprint 2'de Matematik Savaşı'nı başlatacak.
## Orijin hücrenin alt ortasıdır.

signal reached

var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 180)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -90)
	add_child(cs)
	body_entered.connect(func(body: Node2D) -> void:
		if body is Player:
			set_deferred("monitoring", false)
			reached.emit())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var stone := Color("8a8f9c")
	draw_rect(Rect2(-70, -190, 26, 190), stone)
	draw_rect(Rect2(44, -190, 26, 190), stone)
	draw_rect(Rect2(-78, -214, 156, 30), stone.darkened(0.15))
	draw_rect(Rect2(-44, -184, 88, 184), Color(0.35, 0.8, 1.0, 0.25 + 0.1 * sin(_t * 2.0)))
	var c := Vector2(0, -232 + sin(_t * 2.5) * 5.0)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -26), c + Vector2(18, 0), c + Vector2(0, 26), c + Vector2(-18, 0)]),
		Color("6fe3ff"))
	draw_circle(c, 34, Color(0.6, 0.95, 1.0, 0.18))
