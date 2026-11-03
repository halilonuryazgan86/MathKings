extends Control
## Kahraman seçimi. Karakterler yalnızca görsel olarak farklıdır (oyun avantajı yok).

var _selected := ""

@onready var _cards: HBoxContainer = %Cards
@onready var _start: Button = %StartButton


func _ready() -> void:
	_selected = GameState.save.character()
	var group := ButtonGroup.new()
	for id in SaveData.CHARACTER_IDS:
		_cards.add_child(_make_card(id, group))
	%BackButton.pressed.connect(_back)
	_start.pressed.connect(_on_start)
	_start.grab_focus()


func _make_card(id: String, group: ButtonGroup) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.button_group = group
	card.button_pressed = id == _selected
	card.custom_minimum_size = Vector2(300, 380)
	card.pressed.connect(func() -> void: _selected = id)

	var preview := CharacterVisual.new()
	preview.character_id = id
	preview.position = Vector2(150, 210)
	preview.scale = Vector2(1.5, 1.5)
	card.add_child(preview)

	var name_label := Label.new()
	name_label.text = "CHAR_" + id.to_upper()
	name_label.add_theme_font_size_override("font_size", 38)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(0, 228)
	name_label.size = Vector2(300, 50)
	card.add_child(name_label)

	var desc := Label.new()
	desc.text = "CHAR_%s_DESC" % id.to_upper()
	desc.add_theme_font_size_override("font_size", 22)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.position = Vector2(16, 282)
	desc.size = Vector2(268, 90)
	card.add_child(desc)
	return card


func _on_start() -> void:
	if GameState.save.set_character(_selected):
		GameState.persist()
		GameState.start_level(GameState.FIRST_LEVEL_ID)


func _back() -> void:
	GameState.go_to(GameState.SCENE_MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
