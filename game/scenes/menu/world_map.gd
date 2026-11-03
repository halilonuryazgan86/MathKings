extends Control
## Krallık Haritası: dünyalar ve bölümler. Sınıf önerisi yalnızca bilgilendirir; zorunluluk yoktur.

@onready var _worlds: HBoxContainer = %Worlds


func _ready() -> void:
	Music.play("menu")
	%BackButton.pressed.connect(_back)
	var grade := GameState.save.grade()
	for world in GameState.worlds():
		_worlds.add_child(_make_card(world, grade))


func _make_card(world: Dictionary, grade: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(330, 430)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var title := _label(tr(world.nameKey), 30, Color(1, 0.9, 0.5))
	box.add_child(title)

	var grades: Array = world.get("grades", [])
	var range_text := tr("MAP_GRADES").format({"from": int(grades.min()), "to": int(grades.max())})
	box.add_child(_label(range_text, 20, Color.WHITE))
	if world.get("comingSoon", false):
		box.add_child(_label(tr("MAP_COMING_SOON"), 24, Color(0.8, 0.8, 0.8)))
		card.modulate = Color(1, 1, 1, 0.6)
		return card
	var fits := Progression.is_recommended(world, grade)
	box.add_child(_label(tr("MAP_FITS" if fits else "MAP_EXPLORE"), 20,
		Color(0.7, 1, 0.7) if fits else Color(1, 0.85, 0.6)))

	for level in world.levels:
		var b := Button.new()
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.add_theme_font_size_override("font_size", 24)
		b.custom_minimum_size = Vector2(0, 80)
		if GameState.is_level_unlocked(level.id):
			b.text = tr("MAP_LEVEL").format({
				"name": tr(level.nameKey),
				"stars": GameState.save.star_count(level.id),
				"battle": GameState.save.battle_stars(level.id)})
			b.pressed.connect(GameState.start_level.bind(level.id))
		else:
			b.text = tr("MAP_LOCKED").format({"name": tr(level.nameKey)})
			b.disabled = true
		box.add_child(b)
	return card


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _back() -> void:
	GameState.go_to(GameState.SCENE_MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
