extends SceneTree
## Geçici orman tile görselini üretir (nihai sanat gelene kadar).
## Çalıştırma: godot --headless --path game -s res://tools/generate_placeholder_tiles.gd

const T := 64
const OUT := "res://assets/tiles/forest_tiles.png"

const GRASS := Color("5cbf4a")
const GRASS_DARK := Color("3f9a36")
const DIRT := Color("9a6538")
const DIRT_DARK := Color("7c4e2a")
const DIRT_LIGHT := Color("b07a48")
const WOOD := Color("c58a4a")
const WOOD_DARK := Color("8e5a2c")


func _initialize() -> void:
	var img := Image.create(T * 3, T, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# 0: çimenli zemin, 1: toprak
	for tile in 2:
		var ox := tile * T
		img.fill_rect(Rect2i(ox, 0, T, T), DIRT)
		for i in 14:
			var c := DIRT_DARK if i % 2 == 0 else DIRT_LIGHT
			img.fill_rect(Rect2i(ox + rng.randi_range(4, T - 10), rng.randi_range(4, T - 8), 6, 4), c)
		if tile == 0:
			img.fill_rect(Rect2i(ox, 0, T, 16), GRASS)
			img.fill_rect(Rect2i(ox, 16, T, 4), GRASS_DARK)
			for x in range(0, T, 8):
				img.fill_rect(Rect2i(ox + x + 2, 20, 4, 4 + (x / 8) % 3 * 2), GRASS_DARK)

	# 2: ahşap platform (üst 24 px)
	var px := 2 * T
	img.fill_rect(Rect2i(px, 0, T, 22), WOOD)
	img.fill_rect(Rect2i(px, 18, T, 4), WOOD_DARK)
	img.fill_rect(Rect2i(px + 31, 0, 2, 22), WOOD_DARK)
	img.fill_rect(Rect2i(px + 8, 22, 6, 10), WOOD_DARK)
	img.fill_rect(Rect2i(px + T - 14, 22, 6, 10), WOOD_DARK)

	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err := img.save_png(OUT)
	print("Yazıldı: %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)
