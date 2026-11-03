class_name BridgeArt
extends Control
## İki kıyı arasında su ve yerleştirilen köprü tahtaları.

const TOTAL := 3

var planks := 0:
	set(value):
		planks = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cliff := w * 0.18
	draw_rect(Rect2(cliff, h * 0.55, w - cliff * 2, h * 0.45), Color(0.16, 0.6, 0.85))
	for side in [0.0, w - cliff]:
		draw_rect(Rect2(side, h * 0.35, cliff, h * 0.65), Color("c9955a"))
		draw_rect(Rect2(side, h * 0.35, cliff, h * 0.1), Color("f2d48a"))
	var span := (w - cliff * 2) / TOTAL
	for i in TOTAL:
		var r := Rect2(cliff + i * span + 3, h * 0.35, span - 6, h * 0.12)
		if i < planks:
			draw_rect(r, Color("a0703c"))
			draw_rect(r, Color("6e4a24"), false, 3.0)
		else:
			draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)
