class_name TreasureHunt
extends QuizOverlay
## Hazine Avı: 3 matematik ipucunu çözerek haritadaki doğru taşlara basılır, hazine bulunur.
## İsteğe bağlıdır; "Vazgeç" ile çıkılabilir.

const ROUNDS := 3
const TILES := 12

var _gen: QuestionGenerator
var _round := 0

@onready var _grid: GridContainer = %Grid
@onready var _clue: Label = %Clue
@onready var _steps: Label = %Steps
@onready var _chest: ChestArt = %ChestArt


func _ready() -> void:
	super()
	_make_buttons(_grid, TILES, Vector2(180, 88), 40)
	%QuitButton.pressed.connect(func() -> void: _close(false))


func start(grade: int) -> void:
	_gen = QuestionGenerator.for_grade(grade)
	_round = 0
	_chest.opened = false
	_chest.hide()
	_grid.show()
	_open()
	_show_hint(tr("TREASURE_INTRO"))
	_next_round()


func _next_round() -> void:
	_round += 1
	var q := _gen.next()
	_steps.text = tr("TREASURE_STEP").format({"i": _round, "n": ROUNDS})
	_clue.text = tr("TREASURE_CLUE").format({"expr": q.expression})
	var values: Array = q.choices.duplicate()
	while values.size() < TILES:
		var v: int = int(q.answer) + randi_range(-25, 25)
		if v >= 0 and v not in values:
			values.append(v)
	values.shuffle()
	_ask(q, values)


func _correct(_button: Button) -> void:
	await _wait(0.6)
	await _advance()


func _revealed() -> void:
	await _advance()


func _advance() -> void:
	if _round < ROUNDS:
		_hint_panel.hide()
		_next_round()
		return
	_grid.hide()
	_chest.show()
	_chest.opened = true
	_clue.text = tr("TREASURE_FOUND_TITLE")
	Sfx.play(self, "win")
	_show_hint(tr("TREASURE_FOUND").format({"gold": SaveData.TREASURE_GOLD}))
	await _wait(2.4)
	_close(true)
