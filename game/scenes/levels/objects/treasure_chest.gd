class_name TreasureChest
extends Area2D
## Hazine Avı sandığı (isteğe bağlı). Dokununca Hazine Avı açılır; bulunmuşsa açık görünür.
## Orijin hücrenin alt ortasıdır.

signal reached(chest: TreasureChest)

var item_id := ""
var opened := false:
	set(value):
		opened = value
		queue_redraw()
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := RectangleShape2D.new()
	shape.size = Vector2(72, 64)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -32)
	add_child(cs)
	add_child(OffscreenPause.make(Rect2(-50, -80, 100, 80)))
	body_entered.connect(func(body: Node2D) -> void:
		if body is Player and not opened:
			reached.emit(self))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not opened:
		draw_circle(Vector2(0, -30), 46 + sin(_t * 3.0) * 4.0, Color(1, 0.9, 0.4, 0.18))
	draw_chest(self, Vector2(0, -22), 1.0, opened)


static func draw_chest(ci: CanvasItem, center: Vector2, s: float, is_open: bool) -> void:
	var wood := Color("a0622d")
	var band := Color("ffcc33")
	ci.draw_rect(Rect2(center + Vector2(-30, -6) * s, Vector2(60, 28) * s), wood)
	ci.draw_rect(Rect2(center + Vector2(-30, 4) * s, Vector2(60, 5) * s), band)
	if is_open:
		ci.draw_rect(Rect2(center + Vector2(-30, -34) * s, Vector2(60, 10) * s), wood.darkened(0.2))
		for i in 3:
			Pickup.draw_coin(ci, center + Vector2(-14 + i * 14, -12) * s, 8 * s)
	else:
		ci.draw_rect(Rect2(center + Vector2(-32, -22) * s, Vector2(64, 18) * s), wood.lightened(0.1))
		ci.draw_rect(Rect2(center + Vector2(-5, -12) * s, Vector2(10, 12) * s), band)
