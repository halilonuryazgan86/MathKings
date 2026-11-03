class_name CharacterVisual
extends Node2D
## Geçici, kodla çizilen karakter görseli. Orijin ayak ortasıdır.
## Nihai sanatta AnimatedSprite2D ile değiştirilecek; play(anim) arayüzü aynı kalır.

const STYLES := {
	"arin": {"body": Color("3fa34d"), "accent": Color("8b5a2b"), "skin": Color("f2c29b"), "hair": Color("5a3418")},
	"lina": {"body": Color("8e5cd9"), "accent": Color("ffcc33"), "skin": Color("e8b48a"), "hair": Color("c0552b")},
	"bora": {"body": Color("e0662f"), "accent": Color("3c6fd1"), "skin": Color("c98f65"), "hair": Color("2b1d14")},
}
const INK := Color("2b2118")

@export var character_id := "arin":
	set(value):
		character_id = value if STYLES.has(value) else "arin"
		_body_box = null
		queue_redraw()

var animation := "idle"
var facing := 1.0
var _t := 0.0
var _body_box: StyleBoxFlat


func play(anim: String) -> void:
	if anim != animation:
		animation = anim
		_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var st: Dictionary = STYLES[character_id]
	var bob := 0.0
	var swing := 0.0
	var squash := Vector2.ONE
	match animation:
		"idle":
			bob = sin(_t * 3.0) * 2.0
		"walk":
			bob = -absf(sin(_t * 12.0)) * 4.0
			swing = sin(_t * 12.0) * 9.0
		"jump":
			squash = Vector2(0.9, 1.1)
		"fall":
			squash = Vector2(1.06, 0.95)
			swing = 4.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(squash.x * facing, squash.y))

	var dark: Color = st.accent.darkened(0.35)
	# Bacaklar
	draw_rect(Rect2(-14 + swing * 0.5, -24, 11, 24), dark)
	draw_rect(Rect2(3 - swing * 0.5, -24, 11, 24), dark)
	# Arka kol
	draw_rect(Rect2(-24 - swing * 0.3, -54, 9, 26), st.body.darkened(0.2))
	# Gövde
	if _body_box == null:
		_body_box = StyleBoxFlat.new()
		_body_box.bg_color = st.body
		_body_box.set_corner_radius_all(14)
		_body_box.border_color = st.body.darkened(0.3)
		_body_box.set_border_width_all(3)
	draw_style_box(_body_box, Rect2(-20, -62, 40, 42))
	draw_rect(Rect2(-20, -32, 40, 6), st.accent)
	# Ön kol
	draw_rect(Rect2(14 + swing * 0.3, -54, 9, 26), st.body.darkened(0.1))
	# Baş
	draw_circle(Vector2(2, -80), 21, st.skin)
	draw_circle(Vector2(2, -80), 21, st.skin.darkened(0.25), false, 2.0)
	# Gözler (bakılan yöne kaymış)
	for ex in [5.0, 15.0]:
		draw_circle(Vector2(ex, -83), 5.0, Color.WHITE)
		draw_circle(Vector2(ex + 1.5, -83), 2.6, INK)
	draw_arc(Vector2(10, -74), 6, 0.3, PI - 0.3, 10, INK, 2.0)
	_draw_headgear(character_id, st)
	draw_set_transform(Vector2.ZERO)


func _draw_headgear(id: String, st: Dictionary) -> void:
	match id:
		"arin":  # Kaşif şapkası
			draw_rect(Rect2(-24, -98, 54, 7), st.accent)
			draw_rect(Rect2(-12, -112, 30, 16), st.accent)
			draw_rect(Rect2(-12, -100, 30, 4), st.accent.darkened(0.3))
		"lina":  # Saç, at kuyruğu ve mucit gözlüğü
			draw_circle(Vector2(-18, -84), 9, st.hair)
			draw_rect(Rect2(-19, -101, 42, 10), st.hair)
			draw_rect(Rect2(-19, -94, 42, 5), st.accent.darkened(0.4))
			for gx in [4.0, 17.0]:
				draw_circle(Vector2(gx, -95), 7, st.accent)
				draw_circle(Vector2(gx, -95), 4, Color("9fe8ff"))
		"bora":  # Kask ve sırtta kalkan
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				pts.append(Vector2(2, -84) + Vector2(cos(a), sin(a)) * 24)
			draw_colored_polygon(pts, st.accent)
			draw_rect(Rect2(-22, -86, 48, 5), st.accent.darkened(0.3))
			draw_circle(Vector2(-26, -42), 14, st.accent)
			draw_circle(Vector2(-26, -42), 14, Color("ffd34d"), false, 3.0)
