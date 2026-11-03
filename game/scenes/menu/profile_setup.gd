extends Control
## Misafir profil kurulumu: hazır listeden takma ad + sınıf. Gerçek ad istenmez.

const ADJECTIVES: Array[String] = ["Cesur", "Hızlı", "Neşeli", "Zeki", "Meraklı", "Parlak", "Sevimli", "Çevik"]
const ANIMALS: Array[String] = ["Tilki", "Kartal", "Panda", "Yunus", "Sincap", "Kaplan", "Penguen", "Ceylan"]

var _nickname := ""
var _grade := 0

@onready var _nick_label: Label = %NicknameLabel
@onready var _grades: HBoxContainer = %Grades
@onready var _continue: Button = %ContinueButton


func _ready() -> void:
	_nickname = GameState.save.nickname()
	_grade = GameState.save.grade()
	if _nickname.is_empty():
		_reroll()
	_nick_label.text = _nickname

	var group := ButtonGroup.new()
	for g in SaveData.GRADES:
		var b := Button.new()
		b.text = tr("GRADE_N").format({"grade": g})
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = g == _grade
		b.custom_minimum_size = Vector2(190, 90)
		b.pressed.connect(func() -> void:
			_grade = g
			_continue.disabled = false)
		_grades.add_child(b)

	_continue.disabled = _grade == 0
	%RerollButton.pressed.connect(_reroll)
	%BackButton.pressed.connect(_back)
	_continue.pressed.connect(_on_continue)


func _reroll() -> void:
	var previous := _nickname
	while _nickname == previous:
		_nickname = "%s %s" % [ADJECTIVES.pick_random(), ANIMALS.pick_random()]
	if is_node_ready():
		_nick_label.text = _nickname


func _on_continue() -> void:
	if GameState.save.set_profile(_nickname, _grade):
		GameState.persist()
		GameState.go_to(GameState.SCENE_CHARACTER_SELECT)


func _back() -> void:
	GameState.go_to(GameState.SCENE_MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
