class_name QuestionGenerator
extends RefCounted
## Sınıfa göre şablonlardan soru üretir. Aralıklar data/questions/*.json içindedir.
## Aynı seed ile aynı soru dizisi üretilir (test edilebilirlik).
## Yanlış seçenekler mümkün olduğunca tipik öğrenci hatalarından türetilir.

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
## section: "grades" (savaş soruları) veya dosyadaki başka bir bölüm (ör. "bridge").
static func for_grade(grade: int, path: String = DEFAULT_PATH, rng_seed: int = -1,
		section: String = "grades") -> QuestionGenerator:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	var grades: Dictionary = parsed.get(section, {}) if parsed is Dictionary else {}
	var g := clampi(grade, 4, 7)
	while g > 4 and not grades.has(str(g)):
		g -= 1
	if not grades.has(str(g)):
		push_error("Soru şablonu bulunamadı: %s [%s]" % [path, section])
		return QuestionGenerator.new([{"type": "add", "weight": 1, "a": [1, 20], "b": [1, 20]}], rng_seed)
	return QuestionGenerator.new(grades[str(g)], rng_seed)


func next() -> MathQuestion:
	var q: MathQuestion
	for attempt in 12:
		q = _make(_pick_type())
		if q.question_text() + str(q.answer) not in _recent:
			break
	_recent.append(q.question_text() + str(q.answer))
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


func _pick(cfg: Dictionary, key: String) -> int:
	var list: Array = cfg[key]
	return int(list[_rng.randi_range(0, list.size() - 1)])


func _make(cfg: Dictionary) -> MathQuestion:
	var q := MathQuestion.new()
	q.topic = cfg.type
	match cfg.type:
		"add", "sub", "mul", "div", "order_mul", "order_paren", "order_mix":
			_make_arithmetic(q, cfg)
		"multiple", "factor", "prime", "divisible":
			_make_number_theory(q, cfg)
		"frac_compare", "frac_equiv", "frac_add", "frac_sub", "frac_of", "frac_mul", "frac_bar":
			_make_fraction(q, cfg)
		_:
			push_error("Bilinmeyen soru tipi: %s" % cfg.type)
			q.expression = "1 + 1"
			q.answer = 2
			q.hint_key = "HINT_ADD_SIMPLE"
			q.choices = _int_choices(2, -1)
	return q


# --- Dört işlem ve işlem önceliği ---------------------------------------------

func _make_arithmetic(q: MathQuestion, cfg: Dictionary) -> void:
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
	q.choices = _int_choices(q.answer, special)


func _split_hint(q: MathQuestion, prefix: String, a: int, b: int) -> void:
	var small := b % 10
	var big := b - small
	if big > 0 and small > 0:
		q.hint_key = prefix + "_SPLIT"
		q.hint_args = {"a": a, "b": b, "big": big, "small": small}
	else:
		q.hint_key = prefix + "_SIMPLE"
		q.hint_args = {"a": a, "b": b}


# --- Çarpanlar, katlar, asal sayılar, bölünebilme ----------------------------

func _make_number_theory(q: MathQuestion, cfg: Dictionary) -> void:
	var wrong: Array[int] = []
	match cfg.type:
		"multiple":
			var n := _r(cfg, "n")
			q.answer = n * _r(cfg, "k")
			for off in [1, -1, 2, -2, 3, -3, 4, -4, 5, -5]:
				var v: int = q.answer + off
				if v > 0 and v % n != 0:
					wrong.append(v)
			q.prompt = TranslationServer.translate("Q_MULTIPLE").format({"n": n})
			q.hint_key = "HINT_MULTIPLE"
			q.hint_args = {"n": n, "n2": n * 2, "n3": n * 3}
			q.meta = {"n": n}
		"factor":
			var a := _r(cfg, "a")
			var b := _r(cfg, "b")
			var n := a * b
			q.answer = a if _rng.randf() < 0.5 else b
			for v in range(2, n + 8):
				if n % v != 0:
					wrong.append(v)
			wrong.sort_custom(func(x: int, y: int) -> bool: return absi(x - q.answer) < absi(y - q.answer))
			wrong = wrong.slice(0, 6)
			q.prompt = TranslationServer.translate("Q_FACTOR").format({"n": n})
			q.hint_key = "HINT_FACTOR"
			q.hint_args = {"n": n}
			q.meta = {"n": n}
		"prime":
			var lo: int = int(cfg.range[0])
			var hi: int = int(cfg.range[1])
			var primes: Array[int] = []
			for v in range(maxi(lo, 2), hi + 1):
				if is_prime(v):
					primes.append(v)
				elif v % 2 == 1 or _rng.randf() < 0.3:  # Tek bileşik sayılar daha öğretici çeldiricidir
					wrong.append(v)
			q.answer = primes[_rng.randi_range(0, primes.size() - 1)]
			q.prompt = TranslationServer.translate("Q_PRIME")
			q.hint_key = "HINT_PRIME"
		"divisible":
			var d := _pick(cfg, "d")
			var lo: int = int(cfg.range[0])
			var hi: int = int(cfg.range[1])
			q.answer = _rng.randi_range(ceili(float(lo) / d), hi / d) * d
			for off in [1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 7, -7]:
				var v: int = q.answer + off
				if v >= lo and v % d != 0:
					wrong.append(v)
			q.prompt = TranslationServer.translate("Q_DIVISIBLE").format({"d": d})
			q.hint_key = "HINT_RULE_%d" % d
			q.meta = {"d": d}
	_shuffle(wrong)
	var choices: Array = [q.answer]
	for v in wrong:
		if choices.size() >= CHOICE_COUNT:
			break
		if v not in choices:
			choices.append(v)
	_shuffle(choices)
	q.choices = choices


static func is_prime(n: int) -> bool:
	if n < 2:
		return false
	for d in range(2, int(sqrt(n)) + 1):
		if n % d == 0:
			return false
	return true


# --- Kesirler ----------------------------------------------------------------

func _make_fraction(q: MathQuestion, cfg: Dictionary) -> void:
	var candidates: Array[String] = []
	match cfg.type:
		"frac_compare":
			var mode := "max" if _rng.randf() < 0.5 else "min"
			var same_den: bool = cfg.get("sameDen", false)
			var fracs: Array[String] = []
			var d := _pick(cfg, "den")
			while fracs.size() < CHOICE_COUNT:
				if not same_den:
					d = _pick(cfg, "den")
				var f := Fraction.text(_rng.randi_range(1, d - 1), d)
				if not fracs.any(func(x: String) -> bool: return Fraction.same_value(x, f)):
					fracs.append(f)
			var best := fracs[0]
			for f in fracs:
				if (Fraction.compare(f, best) > 0) == (mode == "max") and f != best:
					best = f
			q.answer = best
			q.choices = fracs
			_shuffle(q.choices)
			q.prompt = TranslationServer.translate("Q_FRAC_MAX" if mode == "max" else "Q_FRAC_MIN")
			q.hint_key = "HINT_FRAC_SAME_DEN" if same_den else "HINT_FRAC_COMPARE"
			q.meta = {"mode": mode}
			return
		"frac_equiv":
			var base := _coprime_fraction(cfg)
			var p := Fraction.parse(base)
			var k := _r(cfg, "k")
			q.answer = Fraction.text(p.x * k, p.y * k)
			candidates = [Fraction.text(p.x + k, p.y + k), Fraction.text(p.x * k, p.y),
				Fraction.text(p.x, p.y * k), Fraction.text(p.x * k + 1, p.y * k), Fraction.text(p.y, p.x)]
			q.prompt = TranslationServer.translate("Q_FRAC_EQUIV").format({"f": base})
			q.hint_key = "HINT_FRAC_EQUIV"
			q.hint_args = {"k": k}
			q.meta = {"base": base}
		"frac_add", "frac_sub":
			var d := maxi(_pick(cfg, "den"), 3)
			var add: bool = cfg.type == "frac_add"
			var a: int
			var b: int
			if add:  # Sonuç en fazla 1 (d/d)
				a = _rng.randi_range(1, d - 1)
				b = _rng.randi_range(1, d - a)
			else:
				a = _rng.randi_range(2, d - 1)
				b = _rng.randi_range(1, a - 1)
			var result := a + b if add else a - b
			q.expression = "%s %s %s" % [Fraction.text(a, d), "+" if add else "-", Fraction.text(b, d)]
			q.answer = Fraction.text(result, d)
			candidates = [Fraction.text(result, d * 2),   # Paydaları da toplama hatası
				Fraction.text(result + 1, d), Fraction.text(result - 1, d),
				Fraction.text(a - b if add else a + b, d)]  # Ters işlem hatası
			q.hint_key = "HINT_FRAC_ADD" if add else "HINT_FRAC_SUB"
			q.hint_args = {"a": a, "b": b, "d": d}
			q.meta = {"a": a, "b": b, "d": d}
		"frac_mul":
			var a := Fraction.parse(_coprime_fraction(cfg))
			var c := Fraction.parse(_coprime_fraction(cfg))
			q.expression = "%s × %s" % [Fraction.text(a.x, a.y), Fraction.text(c.x, c.y)]
			q.answer = Fraction.text(a.x * c.x, a.y * c.y)
			candidates = [Fraction.text(a.x + c.x, a.y + c.y), Fraction.text(a.x * c.x, a.y + c.y),
				Fraction.text(a.x * c.y, a.y * c.x), Fraction.text(a.x * c.x + 1, a.y * c.y)]
			q.hint_key = "HINT_FRAC_MUL"
			q.hint_args = {"a": a.x, "b": a.y, "c": c.x, "d": c.y}
			q.meta = {"a": a.x, "b": a.y, "c": c.x, "d": c.y}
		"frac_of":
			var b := _pick(cfg, "den")
			var a := _rng.randi_range(1, b - 1)
			var part := _r(cfg, "m")
			var n := b * part
			q.answer = part * a
			q.prompt = TranslationServer.translate("Q_FRAC_OF").format({"n": n, "f": Fraction.text(a, b)})
			q.hint_key = "HINT_FRAC_OF"
			q.hint_args = {"n": n, "a": a, "b": b, "part": part}
			q.meta = {"n": n, "a": a, "b": b}
			q.choices = _int_choices(q.answer, n - q.answer if n - q.answer != q.answer else part)
			return
		"frac_bar":
			var base := _coprime_fraction(cfg)
			var p := Fraction.parse(base)
			var k := _r(cfg, "k")
			q.answer = base
			candidates = [Fraction.text(p.y - p.x, p.y), Fraction.text(p.x * k, p.y), Fraction.text(p.x, p.y * k),
				Fraction.text(p.x + 1, p.y), Fraction.text(p.x, p.y + 1)]
			q.prompt = TranslationServer.translate("Q_BAR_EXACT" if k == 1 else "Q_BAR_EQUIV")
			q.hint_key = "HINT_BAR" if k == 1 else "HINT_BAR_EQUIV"
			q.hint_args = {"n": p.x * k, "d": p.y * k, "k": k}
			q.meta = {"bar_num": p.x * k, "bar_den": p.y * k}
	q.choices = _fraction_choices(q.answer, candidates)


## Sadeleşmiş, 0 ile 1 arasında bir kesir.
func _coprime_fraction(cfg: Dictionary) -> String:
	for attempt in 50:
		var d := _pick(cfg, "den")
		var n := _rng.randi_range(1, d - 1)
		if Fraction.gcd(n, d) == 1:
			return Fraction.text(n, d)
	return "1/2"


func _fraction_choices(answer: String, candidates: Array[String]) -> Array:
	var choices: Array = [answer]
	_shuffle(candidates)
	for c in candidates:
		if choices.size() >= CHOICE_COUNT:
			break
		var p := Fraction.parse(c)
		if p.x > 0 and p.y > 0 and c not in choices and not choices.any(
				func(x: String) -> bool: return Fraction.same_value(x, c)):
			choices.append(c)
	var p0 := Fraction.parse(answer)
	var extra := 1
	while choices.size() < CHOICE_COUNT:
		var c := Fraction.text(p0.x + extra, p0.y + extra)
		if not choices.any(func(x: String) -> bool: return Fraction.same_value(x, c)):
			choices.append(c)
		extra += 1
	_shuffle(choices)
	return choices


# --- Ortak -------------------------------------------------------------------

func _int_choices(answer: int, special: int) -> Array:
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
	var out: Array = pool.duplicate()
	out.append(answer)
	_shuffle(out)
	return out


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
