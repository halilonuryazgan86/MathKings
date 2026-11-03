class_name MathBattle
extends CanvasLayer
## Matematik Savaşı: doğru cevaplar Sayı Canavarı'na sihirli yıldız fırlatır.
## Yanlış cevapta seçenek elenir ve Baykuş ipucu verir; ikinci yanlışta çözüm gösterilir.
## Açıkken oyun dünyası duraklar.

signal finished(stars: int)

const PRAISE_KEYS := ["BATTLE_PRAISE_1", "BATTLE_PRAISE_2", "BATTLE_PRAISE_3", "BATTLE_PRAISE_4"]
const CORRECT_TINT := Color(0.6, 1.0, 0.6)
const WRONG_TINT := Color(0.7, 0.7, 0.7, 0.6)

var _state: BattleState
var _gen: QuestionGenerator
var _buttons: Array[Button] = []
var _busy := false
var _monster_name := ""

@onready var _root: Control = $Root
@onready var _arena: Node2D = %Arena
@onready var _hero: CharacterVisual = %Hero
@onready var _monster: MonsterVisual = %Monster
@onready var _hp: HpBar = %HpBar
@onready var _question: Label = %QuestionLabel
@onready var _hint_panel: Control = %HintPanel
@onready var _hint: Label = %HintLabel
@onready var _answers: HBoxContainer = %Answers
@onready var _continue: Button = %ContinueButton
@onready var _praise: Label = %Praise


func _ready() -> void:
	_root.hide()
	for i in QuestionGenerator.CHOICE_COUNT:
		var b := Button.new()
		b.custom_minimum_size = Vector2(230, 110)
		b.add_theme_font_size_override("font_size", 52)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_answer.bind(b))
		_answers.add_child(b)
		_buttons.append(b)
	_continue.pressed.connect(_next_question)
	%ExitButton.pressed.connect(func() -> void: GameState.go_to(GameState.SCENE_MAIN_MENU))


func is_open() -> bool:
	return _root.visible


## world: worlds.json'daki dünya tanımı (soru dosyası, canavar, tema).
func start(grade: int, character_id: String, world: Dictionary) -> void:
	Music.play("battle")
	_gen = QuestionGenerator.for_grade(grade, world.get("questions", QuestionGenerator.DEFAULT_PATH))
	_state = BattleState.new()
	var monster: Dictionary = world.get("monster", {})
	_monster_name = tr(monster.get("nameKey", "MONSTER_NUMBERS"))
	_monster.body_color = Color(monster.get("color", "6c5ce7"))
	%MonsterName.text = _monster_name
	%Backdrop.backdrop_theme = world.get("theme", "forest")
	_hero.character_id = character_id
	_hero.play("idle")
	_monster.play("idle")
	_hp.max_value = BattleState.MONSTER_HP
	_hp.value = _state.monster_hp
	_answers.show()
	get_tree().paused = true
	_root.show()
	_show_hint(tr("BATTLE_INTRO"))
	_next_question(false)


func _next_question(clear_hint := true) -> void:
	_continue.hide()
	if clear_hint:
		_hint_panel.hide()
	var q := _gen.next()
	_state.start_question(q)
	_question.text = q.question_text()
	# Metin soruları daha uzun: küçük yazı + satır kaydırma, panel taşmasın.
	_question.add_theme_font_size_override("font_size", 64 if q.prompt.is_empty() else 38)
	for i in _buttons.size():
		var b := _buttons[i]
		b.text = str(q.choices[i])
		b.set_meta("value", q.choices[i])
		b.disabled = false
		b.modulate = Color.WHITE
	_busy = false


func _on_answer(button: Button) -> void:
	if _busy:
		return
	var q := _state.current
	var first_try := _state.attempts_on_current == 0
	match _state.answer(button.get_meta("value")):
		BattleState.Result.CORRECT:
			GameState.save.record_answer(q.topic, first_try)
			_on_correct(button)
		BattleState.Result.WRONG_HINT:
			button.disabled = true
			button.modulate = WRONG_TINT
			Sfx.play(self, "wrong")
			_monster.play("taunt")
			_show_hint(tr("BATTLE_ALMOST") + " " + q.hint_text())
		BattleState.Result.WRONG_REVEAL:
			GameState.save.record_answer(q.topic, false)
			_busy = true
			Sfx.play(self, "wrong")
			for b in _buttons:
				var is_answer := q.is_correct(b.get_meta("value"))
				b.disabled = not is_answer
				b.modulate = CORRECT_TINT if is_answer else WRONG_TINT
			_show_hint(q.solution_text())
			_continue.show()
			_continue.grab_focus()


func _on_correct(button: Button) -> void:
	_busy = true
	for b in _buttons:
		b.disabled = b != button
	button.modulate = CORRECT_TINT
	_hint_panel.hide()
	Sfx.play(self, "correct")
	_show_praise()
	await _attack()
	_hp.value = _state.monster_hp
	if _state.is_won():
		await _victory()
	else:
		await get_tree().create_timer(0.3).timeout
		_next_question()


func _attack() -> void:
	var home := _hero.position
	_hero.play("attack")
	var lunge := create_tween()
	lunge.tween_property(_hero, "position:x", home.x + 90.0, 0.12)
	await lunge.finished

	var star := _make_star(18.0, Color("ffe14d"))
	star.position = _hero.position + Vector2(70, -120)
	_arena.add_child(star)
	var fly := create_tween()
	fly.tween_property(star, "position", _monster.position + Vector2(0, -90), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(star, "rotation", TAU, 0.3)
	create_tween().tween_property(_hero, "position:x", home.x, 0.2)
	await fly.finished

	star.queue_free()
	_monster.play("hit")
	Sfx.play(self, "hit")
	_hero.play("idle")
	await get_tree().create_timer(0.45).timeout


func _victory() -> void:
	_answers.hide()
	_question.text = tr("BATTLE_VICTORY")
	_monster.play("defeated")
	_hero.play("cheer")
	Sfx.play(self, "win")
	_show_hint(tr("BATTLE_WIN").format({"monster": _monster_name}))

	var crystal := Polygon2D.new()
	crystal.polygon = PackedVector2Array([Vector2(0, -34), Vector2(22, 0), Vector2(0, 34), Vector2(-22, 0)])
	crystal.color = Color("6fe3ff")
	crystal.position = _monster.position + Vector2(0, -120)
	crystal.scale = Vector2.ZERO
	_arena.add_child(crystal)
	var tw := create_tween().set_parallel()
	tw.tween_property(crystal, "scale", Vector2(1.6, 1.6), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(crystal, "position:y", crystal.position.y - 40.0, 0.8)
	await get_tree().create_timer(2.8).timeout

	crystal.queue_free()
	_root.hide()
	get_tree().paused = false
	finished.emit(_state.stars())


func _show_hint(text: String) -> void:
	_hint.text = text
	_hint_panel.show()


func _show_praise() -> void:
	_praise.text = tr(PRAISE_KEYS.pick_random())
	_praise.modulate.a = 1.0
	_praise.show()
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_praise, "modulate:a", 0.0, 0.4)


static func _make_star(r: float, color: Color) -> Polygon2D:
	var pts := PackedVector2Array()
	for i in 10:
		var radius := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	var star := Polygon2D.new()
	star.polygon = pts
	star.color = color
	return star
