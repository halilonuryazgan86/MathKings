class_name QuestionGenerator
extends RefCounted
## Sınıfa göre şablonlardan soru üretir. Aralıklar data/questions/*.json içindedir.
## Aynı seed ile aynı soru dizisi üretilir (test edilebilirlik).

const DEFAULT_PATH := "res://data/questions/numbers_forest.json"
const RECENT_LIMIT := 8
const CHOICE_COUNT := 4

var _types: Array = []
var _rng := RandomNumberGenerator.new()
var _recent: Array[String] = []


func _init(types: Array, rng_seed: int = -1) -> void:
	_types = types
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


## Sınıfın şablonlarını yükler; sınıf yoksa en yakın alt sınıfı (en az 4) kullanır.
static func for_grade(grade: int, path: String = DEFAULT_PATH, rng_seed: int = -1) -> QuestionGenerator:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	var grades: Dictionary = parsed.get("grades", {}) if parsed is Dictionary else {}
	var g := clampi(grade, 4, 7)
	while g > 4 and not grades.has(str(g)):
		g -= 1
	if not grades.has(str(g)):
		push_error("Soru şablonu bulunamadı: %s" % path)
		return QuestionGenerator.new([{"type": "add", "weight": 1, "a": [1, 20], "b": [1, 20]}], rng_seed)
	return QuestionGenerator.new(grades[str(g)], rng_seed)


func next() -> MathQuestion:
	var q: MathQuestion
	for attempt in 12:
		q = _make(_pick_type())
		if q.expression not in _recent:
			break
	_recent.append(q.expression)
	if _recent.size() > RECENT_LIMIT:
		_recent.pop_front()
	return q


func _pick_type() -> Dictionary:
	var total := 0
	for t in _types:
		total += int(t.get("weight", 1))
	var roll := _rng.randi_range(1, total)
	for t in _types:
		roll -= int(t.get("weight", 1))
		if roll <= 0:
			return t
	return _types[0]


func _r(cfg: Dictionary, key: String) -> int:
	var range_: Array = cfg[key]
	return _rng.randi_range(int(range_[0]), int(range_[1]))


func _make(cfg: Dictionary) -> MathQuestion:
	var q := MathQuestion.new()
	q.topic = cfg.type
	var special := -1  # Tipik hatadan gelen çeldirici
	match cfg.type:
		"add":
			var a := _r(cfg, "a")
			var b := _r(cfg, "b")
			q.expression = "%d + %d" % [a, b]
			q.answer = a + b
			_split_hint(q, "HINT_ADD", a, b)
		"sub":
			var a := _r(cfg, "a")
			var b := _r(cfg, "b")
			if b > a:
				var t := a
				a = b
				b = t
			q.expression = "%d - %d" % [a, b]
			q.answer = a - b
			_split_hint(q, "HINT_SUB", a, b)
		"mul":
			var a := _r(cfg, "a")
			var b := _r(cfg, "b")
			q.expression = "%d × %d" % [a, b]
			q.answer = a * b
			special = a * (b + 1)
			if b >= 4:
				var b2 := b % 10 if b >= 10 and b % 10 != 0 else b / 2
				q.hint_key = "HINT_MUL_SPLIT"
				q.hint_args = {"a": a, "b": b, "b1": b - b2, "b2": b2}
			else:
				q.hint_key = "HINT_MUL_REPEAT"
				q.hint_args = {"a": a, "b": b}
		"div":
			var b := _r(cfg, "b")
			var quotient := _r(cfg, "q")
			var a := b * quotient
			q.expression = "%d ÷ %d" % [a, b]
			q.answer = quotient
			q.hint_key = "HINT_DIV"
			q.hint_args = {"a": a, "b": b}
		"order_mul":
			var a := _r(cfg, "a")
			var b := _r(cfg, "b")
			var c := _r(cfg, "c")
			var minus := a >= b * c and _rng.randf() < 0.4
			var op := "-" if minus else "+"
			q.expression = "%d %s %d × %d" % [a, op, b, c]
			q.answer = a - b * c if minus else a + b * c
			special = (a - b) * c if minus else (a + b) * c  # Soldan sağa yapma hatası
			q.hint_key = "HINT_ORDER_MUL"
			q.hint_args = {"a": a, "b": b, "c": c, "bc": b * c, "op": op}
		"order_paren":
			var a := _r(cfg, "a")
			var b := _r(cfg, "b")
			var c := _r(cfg, "c")
			var minus := a > b and _rng.randf() < 0.4
			var op := "-" if minus else "+"
			var inner := a - b if minus else a + b
			q.expression = "(%d %s %d) × %d" % [a, op, b, c]
			q.answer = inner * c
			special = a - b * c if minus else a + b * c  # Parantezi yok sayma hatası
			q.hint_key = "HINT_ORDER_PAREN"
			q.hint_args = {"a": a, "b": b, "c": c, "ab": inner, "op": op}
		"order_mix":
			var a := _r(cfg, "a")
			var b := _r(cfg, "b")
			var c := _r(cfg, "c")
			var d := _r(cfg, "d")
			q.expression = "%d × %d + %d × %d" % [a, b, c, d]
			q.answer = a * b + c * d
			special = (a * b + c) * d  # Soldan sağa yapma hatası
			q.hint_key = "HINT_ORDER_MIX"
			q.hint_args = {"a": a, "b": b, "c": c, "d": d, "ab": a * b, "cd": c * d}
		_:
			push_error("Bilinmeyen soru tipi: %s" % cfg.type)
			q.expression = "1 + 1"
			q.answer = 2
			q.hint_key = "HINT_ADD_SIMPLE"
	q.choices = _choices(q.answer, special)
	return q


func _split_hint(q: MathQuestion, prefix: String, a: int, b: int) -> void:
	var small := b % 10
	var big := b - small
	if big > 0 and small > 0:
		q.hint_key = prefix + "_SPLIT"
		q.hint_args = {"a": a, "b": b, "big": big, "small": small}
	else:
		q.hint_key = prefix + "_SIMPLE"
		q.hint_args = {"a": a, "b": b}


func _choices(answer: int, special: int) -> Array[int]:
	var pool: Array[int] = []
	if special >= 0 and special != answer:
		pool.append(special)
	var near: Array[int] = [answer + 1, answer - 1, answer + 10, answer - 10, answer + 2, answer - 2]
	_shuffle(near)
	for v in near:
		if pool.size() >= CHOICE_COUNT - 1:
			break
		if v >= 0 and v != answer and v not in pool:
			pool.append(v)
	while pool.size() < CHOICE_COUNT - 1:
		var v := answer + _rng.randi_range(3, 20)
		if v not in pool:
			pool.append(v)
	pool.append(answer)
	_shuffle(pool)
	return pool


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
