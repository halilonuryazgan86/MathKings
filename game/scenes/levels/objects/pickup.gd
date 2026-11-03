class_name Pickup
extends Area2D
## Altın veya yıldız. Daha önce toplanmışsa soluk görünür ve tekrar ödül vermez.

signal picked(pickup: Pickup)

enum Kind { COIN, STAR }

var kind := Kind.COIN
var item_id := ""
var already_collected := false
var _t := 0.0
var _art := Node2D.new()  # Bir kez çizilir; sallanma yalnızca konumla yapılır (ucuz).


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CircleShape2D.new()
	shape.radius = 24.0 if kind == Kind.COIN else 30.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	_art.draw.connect(func() -> void:
		if kind == Kind.COIN:
			draw_coin(_art, Vector2.ZERO, 18.0)
		else:
			draw_star(_art, Vector2.ZERO, 26.0))
	add_child(_art)
	add_child(OffscreenPause.make(Rect2(-32, -40, 64, 80)))
	_t = randf() * TAU
	if already_collected:
		modulate.a = 0.35
	body_entered.connect(_on_body_entered)


func gold_value() -> int:
	return SaveData.item_gold(item_id)


func _process(delta: float) -> void:
	_t += delta
	_art.position.y = sin(_t * 3.0) * 4.0


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	set_deferred("monitoring", false)
	picked.emit(self)
	set_process(false)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y - 40.0, 0.25)
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)


static func draw_coin(ci: CanvasItem, center: Vector2, r: float) -> void:
	ci.draw_circle(center, r, Color("e9a514"))
	ci.draw_circle(center, r * 0.78, Color("ffd54a"))
	ci.draw_rect(Rect2(center + Vector2(-r * 0.12, -r * 0.45), Vector2(r * 0.24, r * 0.9)), Color("e9a514"))


static func draw_star(ci: CanvasItem, center: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var radius := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	ci.draw_colored_polygon(pts, Color("ffe14d"))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color("e0a10c"), 3.0)
