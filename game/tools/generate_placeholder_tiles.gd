extends SceneTree
## Geçici tile görselini üretir (nihai sanat gelene kadar).
## Satır = tema (0 orman, 1 mağara, 2 ada); sütun: 0 üst zemin, 1 iç zemin, 2 platform.
## Çalıştırma: godot --headless --path game -s res://tools/generate_placeholder_tiles.gd

const T := 64
const OUT := "res://assets/tiles/world_tiles.png"

const PALETTES := [
	{"top": "5cbf4a", "top_dark": "3f9a36", "base": "9a6538", "dark": "7c4e2a", "light": "b07a48", "plank": "c58a4a", "plank_dark": "8e5a2c"},
	{"top": "9b8fb5", "top_dark": "6f6390", "base": "4b4361", "dark": "3a3350", "light": "5d5478", "plank": "a39cbc", "plank_dark": "6f6890"},
	{"top": "f2d48a", "top_dark": "d9b866", "base": "c9955a", "dark": "a9784a", "light": "dcae74", "plank": "a0703c", "plank_dark": "6e4a24"},
]


func _initialize() -> void:
	var img := Image.create(T * 3, T * PALETTES.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for row in PALETTES.size():
		var p: Dictionary = PALETTES[row]
		var oy := row * T
		for tile in 2:
			var ox := tile * T
			img.fill_rect(Rect2i(ox, oy, T, T), Color(p.base))
			for i in 14:
				var c := Color(p.dark) if i % 2 == 0 else Color(p.light)
				img.fill_rect(Rect2i(ox + rng.randi_range(4, T - 10), oy + rng.randi_range(4, T - 8), 6, 4), c)
			if tile == 0:
				img.fill_rect(Rect2i(ox, oy, T, 16), Color(p.top))
				img.fill_rect(Rect2i(ox, oy + 16, T, 4), Color(p.top_dark))
				for x in range(0, T, 8):
					img.fill_rect(Rect2i(ox + x + 2, oy + 20, 4, 4 + (x / 8) % 3 * 2), Color(p.top_dark))
		var px := 2 * T
		img.fill_rect(Rect2i(px, oy, T, 22), Color(p.plank))
		img.fill_rect(Rect2i(px, oy + 18, T, 4), Color(p.plank_dark))
		img.fill_rect(Rect2i(px + 31, oy, 2, 22), Color(p.plank_dark))
		img.fill_rect(Rect2i(px + 8, oy + 22, 6, 10), Color(p.plank_dark))
		img.fill_rect(Rect2i(px + T - 14, oy + 22, 6, 10), Color(p.plank_dark))

	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err := img.save_png(OUT)
	print("Yazıldı: %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)
