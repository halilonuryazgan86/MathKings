extends Control
## Geçici, kodla çizilen arka plan. Tema: forest (orman), cave (mağara), island (ada).

const THEMES := {
	"forest": {"sky": ["4fb3e8", "c4ecff"], "sun": "fff3a3", "far": "8fd07a", "near": "5fb052",
		"deco_far": "4f9d4a", "deco_near": "2f7a3a", "deco": "tree"},
	"cave": {"sky": ["231b33", "4a3b66"], "sun": "", "far": "3b3156", "near": "2c2442",
		"deco_far": "54476f", "deco_near": "40355a", "deco": "stalagmite"},
	"island": {"sky": ["4fc3f7", "d6f2ff"], "sun": "fff3a3", "far": "29a3d9", "near": "f2d48a",
		"deco_far": "2e9e57", "deco_near": "1f7a43", "deco": "palm"},
}

@export var backdrop_theme := "forest":
	set(value):
		backdrop_theme = value if THEMES.has(value) else "forest"
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var t: Dictionary = THEMES[backdrop_theme]
	var s := size
	var steps := 24
	for i in steps:
		var k := float(i) / steps
		draw_rect(Rect2(0, s.y * k, s.x, s.y / steps + 1.0), Color(t.sky[0]).lerp(Color(t.sky[1]), k))
	if not t.sun.is_empty():
		draw_circle(Vector2(s.x * 0.84, s.y * 0.17), s.y * 0.08, Color(t.sun))
	if backdrop_theme == "cave":
		_ceiling(Color(t.near))
		_crystals()
	if backdrop_theme == "island":
		_sea(s.y * 0.62, Color(t.far))
	else:
		_hills(s.y * 0.62, 30.0, 0.006, 0.0, Color(t.far))
	_decor(s.y * 0.66, 0.75, Color(t.deco_far), t.deco)
	_hills(s.y * 0.78, 22.0, 0.009, 1.7, Color(t.near))
	_decor(s.y * 0.82, 1.0, Color(t.deco_near), t.deco)


func _hills(base_y: float, amp: float, freq: float, phase: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var x := size.x * i / n
		pts.append(Vector2(x, base_y + sin(x * freq + phase) * amp))
	pts.append(Vector2(size.x, size.y))
	pts.append(Vector2(0, size.y))
	draw_colored_polygon(pts, color)


func _sea(base_y: float, color: Color) -> void:
	draw_rect(Rect2(0, base_y, size.x, size.y - base_y), color)
	for row in 3:
		var y := base_y + 18.0 + row * 26.0
		for x in range(0, int(size.x), 90):
			draw_arc(Vector2(x + row * 30, y), 14, PI + 0.4, TAU - 0.4, 8, Color(1, 1, 1, 0.45), 3.0)


func _ceiling(color: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, 0)])
	var n := 24
	for i in n + 1:
		var x := size.x * i / n
		pts.append(Vector2(x, 40.0 + (70.0 if i % 2 == 1 else 0.0) + fmod(i * 37.0, 30.0)))
	pts.append(Vector2(size.x, 0))
	draw_colored_polygon(pts, color)


func _crystals() -> void:
	for i in 7:
		var c := Vector2(fmod(i * 233.0 + 90.0, size.x), size.y * (0.3 + fmod(i * 0.17, 0.25)))
		var r := 10.0 + fmod(i * 7.0, 12.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.6), c + Vector2(r * 0.7, 0),
			c + Vector2(0, r * 1.6), c + Vector2(-r * 0.7, 0)]), Color(0.45, 0.9, 1.0, 0.55))


func _decor(base_y: float, scale_f: float, color: Color, kind: String) -> void:
	var spacing := 170.0 * scale_f
	var count := int(size.x / spacing) + 2
	for i in count:
		var x := i * spacing + fmod(i * 53.0, 60.0)
		var h := (90.0 + fmod(i * 37.0, 50.0)) * scale_f
		match kind:
			"tree":
				draw_rect(Rect2(x - 7 * scale_f, base_y - h * 0.4, 14 * scale_f, h * 0.4 + 40), Color("6b4a2b"))
				draw_circle(Vector2(x, base_y - h * 0.55), h * 0.35, color)
				draw_circle(Vector2(x - h * 0.2, base_y - h * 0.4), h * 0.25, color)
				draw_circle(Vector2(x + h * 0.2, base_y - h * 0.4), h * 0.25, color)
			"stalagmite":
				draw_colored_polygon(PackedVector2Array([Vector2(x - h * 0.25, base_y + 40),
					Vector2(x, base_y - h * 0.8), Vector2(x + h * 0.25, base_y + 40)]), color)
			"palm":
				if i % 2 == 1:
					continue
				var top := Vector2(x + h * 0.15, base_y - h)
				draw_line(Vector2(x, base_y + 40), top, Color("8d6e4a"), 9.0 * scale_f)
				for a in [-2.6, -2.0, -1.2, -0.5]:
					draw_line(top, top + Vector2(cos(a), sin(a) + 0.6) * h * 0.45, color, 10.0 * scale_f)
