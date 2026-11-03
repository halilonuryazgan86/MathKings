class_name FractionBridge
extends QuizOverlay
## Kesir Köprüsü: şekil modelindeki boyalı kısmı doğru kesirle eşleştirince bir tahta yerleşir.
## 3 tahtayla köprü tamamlanır. Her zaman tamamlanabilir (ikinci yanlışta çözüm gösterilir).

const PLANKS := 3

var _gen: QuestionGenerator
var _built := 0

@onready var _prompt: Label = %Prompt
@onready var _bar: FractionBar = %Bar
@onready var _art: BridgeArt = %BridgeArt
@onready var _answers: HBoxContainer = %Answers


func _ready() -> void:
	super()
	_make_buttons(_answers, QuestionGenerator.CHOICE_COUNT, Vector2(220, 100), 44)


func start(grade: int, questions_path: String) -> void:
	_gen = QuestionGenerator.for_grade(grade, questions_path, -1, "bridge")
	_built = 0
	_art.planks = 0
	_answers.show()
	_bar.show()
	_open()
	_show_hint(tr("BRIDGE_INTRO"))
	_next()


func _next() -> void:
	var q := _gen.next()
	_prompt.text = q.prompt
	_bar.set_fraction(int(q.meta.bar_num), int(q.meta.bar_den))
	_ask(q, q.choices)


func _correct(_button: Button) -> void:
	await _place_plank()


func _revealed() -> void:
	await _place_plank()


func _place_plank() -> void:
	_built += 1
	_art.planks = _built
	Sfx.play(self, "hit")
	await _wait(0.6)
	if _built < PLANKS:
		_hint_panel.hide()
		_next()
		return
	_answers.hide()
	_bar.hide()
	_prompt.text = tr("BRIDGE_DONE_TITLE")
	Sfx.play(self, "win")
	_show_hint(tr("BRIDGE_DONE"))
	await _wait(2.0)
	_close(true)
