extends SceneTree
## Android ikonlarını üretir: ana ikon (192) ve uyarlanabilir ikon katmanları (432, güvenli alan ortada %66).
## Çalıştırma: godot --headless --path game -s res://tools/generate_icons.gd

const OUT_DIR := "res://assets/icons"

const CROWN := """<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <path d="M48 176 L60 88 L100 128 L128 68 L156 128 L196 88 L208 176 Z" fill="#ffc43d" stroke="#c97f14" stroke-width="8" stroke-linejoin="round"/>
  <rect x="48" y="172" width="160" height="28" rx="8" fill="#ffc43d" stroke="#c97f14" stroke-width="8"/>
  <path d="M128 132 L144 150 L128 168 L112 150 Z" fill="#6fe3ff" stroke="#2a8fb5" stroke-width="5"/>
</svg>"""

const BACKGROUND := """<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 432 432">
  <rect width="432" height="432" fill="#2a6b4a"/>
  <circle cx="216" cy="216" r="150" fill="#317a55"/>
</svg>"""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var ok := true
	# Ana ikon: mevcut icon.svg (256) -> 192
	ok = _save(_svg(FileAccess.get_file_as_string("res://icon.svg"), 0.75), "icon_192.png") and ok
	# Uyarlanabilir ön katman: taç 288 px (güvenli alan) ortada, şeffaf 432 tuval üzerinde.
	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	fg.fill(Color(0, 0, 0, 0))
	var crown := _svg(CROWN, 288.0 / 256.0)
	fg.blit_rect(crown, Rect2i(Vector2i.ZERO, crown.get_size()), Vector2i(72, 60))
	ok = _save(fg, "icon_foreground_432.png") and ok
	ok = _save(_svg(BACKGROUND, 1.0), "icon_background_432.png") and ok
	quit(0 if ok else 1)


func _svg(text: String, scale: float) -> Image:
	var img := Image.new()
	img.load_svg_from_string(text, scale)
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, name: String) -> bool:
	var path := OUT_DIR.path_join(name)
	var err := img.save_png(path)
	print("%s %dx%d %s" % [path, img.get_width(), img.get_height(), error_string(err)])
	return err == OK
