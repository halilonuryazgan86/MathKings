class_name Checkpoint
extends Area2D
## Kontrol noktası bayrağı. Orijin hücrenin alt ortasıdır.

signal reached(checkpoint: Checkpoint)

var active := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 128)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -64)
	add_child(cs)
	body_entered.connect(_on_body_entered)


func activate() -> void:
	active = true
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not active:
		reached.emit(self)


func _draw() -> void:
	draw_rect(Rect2(-4, -120, 8, 120), Color("6b4a2b"))
	var flag := Color("4cd964") if active else Color("b9b9b9")
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -118), Vector2(48, -104), Vector2(4, -90)]), flag)
	draw_circle(Vector2(0, -122), 6, Color("ffd54a"))
