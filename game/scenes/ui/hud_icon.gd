extends Control
## HUD'daki küçük altın/yıldız simgesi.

@export var star := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.45
	if star:
		Pickup.draw_star(self, size / 2.0, r)
	else:
		Pickup.draw_coin(self, size / 2.0, r)
