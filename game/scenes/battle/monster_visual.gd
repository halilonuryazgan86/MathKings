class_name MonsterVisual
extends Node2D
## Sayı Canavarı: korkutucu değil, sevimli ve şakacı. Yenilince dosta dönüşür.
## Orijin ayak ortasıdır. Animasyonlar: idle, hit, taunt, defeated.

const BODY := Color("6c5ce7")
const BELLY := Color("a29bfe")
const FRIENDLY := Color("ff8fb1")
const INK := Color("2b2118")
const SHORT_ANIMS := ["hit", "taunt"]
const SHORT_DURATION := 0.6

var animation := "idle"
var _t := 0.0


func play(anim: String) -> void:
	animation = anim
	_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	if animation in SHORT_ANIMS and _t > SHORT_DURATION:
		play("idle")
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 2.5) * 4.0
	var off := Vector2.ZERO
	var squash := Vector2.ONE
	var body := BODY
	var happy := false
	match animation:
		"hit":
			off.x = sin(_t * 60.0) * 10.0 * (1.0 - _t / SHORT_DURATION)
			body = BODY.lerp(Color.WHITE, maxf(0.0, 1.0 - _t * 3.0))
		"taunt":
			bob = -absf(sin(_t * 14.0)) * 16.0
			squash = Vector2(1.06, 0.94)
		"defeated":
			var k := minf(_t * 2.0, 1.0)
			squash = Vector2.ONE * lerpf(1.0, 0.75, k)
			body = BODY.lerp(FRIENDLY, k)
			happy = true
	draw_set_transform(off + Vector2(0, bob), 0.0, squash)

	# Boynuzlar, ayaklar, gövde, göbek
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(side * 30, -146), Vector2(side * 62, -186), Vector2(side * 58, -136)]), Color("ffb84d"))
		_ellipse(Vector2(side * 42, -8), Vector2(26, 13), body.darkened(0.25))
	_ellipse(Vector2(0, -84), Vector2(88, 80), body)
	_ellipse(Vector2(0, -58), Vector2(52, 42), BELLY.lerp(Color.WHITE, 0.3) if happy else BELLY)
	draw_string(ThemeDB.fallback_font, Vector2(-36, -46), "+ ×", HORIZONTAL_ALIGNMENT_CENTER, 72, 34, body.darkened(0.3))

	# Gözler
	for side in [-1.0, 1.0]:
		var e := Vector2(side * 30, -120)
		if happy:
			draw_arc(e, 12, PI + 0.3, TAU - 0.3, 12, INK, 4.0)
		else:
			draw_circle(e, 17, Color.WHITE)
			var look := Vector2(-4, 2) if animation != "taunt" else Vector2(0, -3)
			draw_circle(e + look, 8, INK)
			draw_circle(e + look + Vector2(-2, -3), 2.5, Color.WHITE)

	# Ağız
	if animation == "taunt":
		_ellipse(Vector2(0, -92), Vector2(18, 12), INK)
		_ellipse(Vector2(0, -86), Vector2(9, 5), Color("ff6b81"))
	else:
		draw_arc(Vector2(0, -100), 20 if happy else 14, 0.35, PI - 0.35, 12, INK, 4.0)
	draw_set_transform(Vector2.ZERO)


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, color)
