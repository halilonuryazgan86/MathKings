class_name FractionBar
extends Control
## Kesir şekil modeli: eşit parçalara bölünmüş şerit, boyalı parçalar paydır.

var num := 1
var den := 2


func set_fraction(n: int, d: int) -> void:
	num = n
	den = maxi(d, 1)
	queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var cell := size.x / den
	for i in den:
		var r := Rect2(i * cell, 0, cell, size.y)
		draw_rect(r, Color("ffb84d") if i < num else Color(1, 1, 1, 0.85))
		draw_rect(r, Color("5a3a20"), false, 3.0)
