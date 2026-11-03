class_name SaveData
extends RefCounted
## Oyuncunun cihazdaki kaydı: veri + kurallar. Dosya işlemi yapmaz (bkz. SaveStore).
## Dışarıdan gelen (bozuk/değiştirilmiş) veri her zaman normalize edilir.

const SCHEMA_VERSION := 1
const GRADES: Array[int] = [4, 5, 6, 7]
const CHARACTER_IDS: Array[String] = ["arin", "lina", "bora"]
const MAX_NICKNAME_LENGTH := 24
# Altın kuralları: sunucudaki ProgressRules ile aynı olmalıdır.
const COIN_PREFIX := "coin_"
const STAR_PREFIX := "star_"
const COIN_GOLD := 1
const STAR_GOLD := 10
const BATTLE_FIRST_WIN_GOLD := 20
const BATTLE_STAR_GOLD := 5

var _data: Dictionary


func _init(source: Dictionary = {}) -> void:
	_data = _normalized(source)


func to_dict() -> Dictionary:
	return _data.duplicate(true)


# --- Profil -----------------------------------------------------------------

func has_profile() -> bool:
	var p: Dictionary = _data.profile
	return p.has("nickname") and p.has("grade") and p.has("character")


func set_profile(nickname: String, grade: int) -> bool:
	if not _is_valid_nickname(nickname) or grade not in GRADES:
		return false
	_data.profile.nickname = nickname
	_data.profile.grade = grade
	return true


func set_character(character_id: String) -> bool:
	if character_id not in CHARACTER_IDS:
		return false
	_data.profile.character = character_id
	return true


func nickname() -> String:
	return _data.profile.get("nickname", "")


func grade() -> int:
	return _data.profile.get("grade", 0)


func character() -> String:
	return _data.profile.get("character", CHARACTER_IDS[0])


func guest_id() -> String:
	return _data.guestId


func seen_intro() -> bool:
	return _data.seenIntro


func mark_intro_seen() -> void:
	_data.seenIntro = true


# --- İlerleme ve ödüller -----------------------------------------------------

## Altın saklanmaz; ilerlemeden hesaplanır. Böylece cihazlar arası birleştirmede
## altın iki kez sayılmaz ve elle değiştirilemez.
func gold() -> int:
	var total := 0
	for lv in _data.levels.values():
		for id: String in lv.collected:
			total += item_gold(id)
		if lv.battleStars > 0:
			total += BATTLE_FIRST_WIN_GOLD + lv.battleStars * BATTLE_STAR_GOLD
	return total


static func item_gold(item_id: String) -> int:
	if item_id.begins_with(STAR_PREFIX):
		return STAR_GOLD
	if item_id.begins_with(COIN_PREFIX):
		return COIN_GOLD
	return 0


## Bir toplanabiliri yalnızca ilk kez kaydeder. Tekrar oynamada false döner.
func collect(level_id: String, item_id: String) -> bool:
	if level_id.is_empty() or item_gold(item_id) == 0 or is_collected(level_id, item_id):
		return false
	_level(level_id).collected.append(item_id)
	return true


func is_collected(level_id: String, item_id: String) -> bool:
	return _data.levels.has(level_id) and item_id in _data.levels[level_id].collected


func star_count(level_id: String) -> int:
	if not _data.levels.has(level_id):
		return 0
	return _data.levels[level_id].collected.filter(
		func(id: String) -> bool: return id.begins_with(STAR_PREFIX)).size()


## Savaş sonucunu kaydeder ve verilen altını döndürür. İlk zafer BATTLE_FIRST_WIN_GOLD,
## her yeni (daha önce ulaşılmamış) yıldız BATTLE_STAR_GOLD verir. Tekrar oynama ödül çoğaltmaz.
func record_battle(level_id: String, stars: int) -> int:
	if level_id.is_empty():
		return 0
	var lv := _level(level_id)
	var new_best := clampi(stars, 1, 3)
	var old_best: int = lv.battleStars
	var reward := BATTLE_FIRST_WIN_GOLD if old_best == 0 else 0
	if new_best > old_best:
		reward += (new_best - old_best) * BATTLE_STAR_GOLD
		lv.battleStars = new_best
	return reward


func battle_stars(level_id: String) -> int:
	return _data.levels[level_id].battleStars if _data.levels.has(level_id) else 0


## Öğrenme istatistiği: konu başına çözülen soru ve ilk denemede doğru sayısı.
func record_answer(topic: String, correct_first_try: bool) -> void:
	if topic.is_empty():
		return
	if not _data.stats.has(topic):
		_data.stats[topic] = {"attempts": 0, "correct": 0}
	_data.stats[topic].attempts += 1
	if correct_first_try:
		_data.stats[topic].correct += 1


func topic_stats(topic: String) -> Dictionary:
	return _data.stats.get(topic, {"attempts": 0, "correct": 0}).duplicate()


# --- Bulut senkronizasyonu ---------------------------------------------------

## Sunucuya gönderilen ilerleme (profil ve misafir kimliği hariç; altın sunucuda hesaplanır).
func progress_dict() -> Dictionary:
	return {
		"seenIntro": _data.seenIntro,
		"levels": _data.levels.duplicate(true),
		"stats": _data.stats.duplicate(true),
	}


## Başka bir cihazın/sunucunun ilerlemesini birleştirir. Sunucudaki ProgressRules.Merge ile aynı:
## toplananlar birleşir, tamamlanma VEYA, savaş yıldızı ve istatistikler en büyüğü.
func merge_progress(other: Dictionary) -> void:
	var o := _normalized(other)
	_data.seenIntro = _data.seenIntro or o.seenIntro
	for id in o.levels:
		var theirs: Dictionary = o.levels[id]
		var mine := _level(id)
		mine.completed = mine.completed or theirs.completed
		mine.battleStars = maxi(mine.battleStars, theirs.battleStars)
		for item in theirs.collected:
			if item not in mine.collected:
				mine.collected.append(item)
	for topic in o.stats:
		var mine: Dictionary = _data.stats.get(topic, {"attempts": 0, "correct": 0})
		var attempts := maxi(mine.attempts, o.stats[topic].attempts)
		_data.stats[topic] = {"attempts": attempts, "correct": mini(maxi(mine.correct, o.stats[topic].correct), attempts)}


## Misafir ilerlemesi bir hesaba aktarıldıysa profil kimliği (tekrar önerilmesin diye).
func linked_profile_id() -> String:
	return _data.linkedProfileId


func set_linked_profile_id(id: String) -> void:
	_data.linkedProfileId = id


## İlk tamamlamada true döner (ileride tek seferlik bölüm ödülü için).
func complete_level(level_id: String) -> bool:
	if level_id.is_empty() or is_level_completed(level_id):
		return false
	_level(level_id).completed = true
	return true


func is_level_completed(level_id: String) -> bool:
	return _data.levels.has(level_id) and _data.levels[level_id].completed


# --- İç yardımcılar ----------------------------------------------------------

func _level(level_id: String) -> Dictionary:
	if not _data.levels.has(level_id):
		_data.levels[level_id] = {"completed": false, "collected": [], "battleStars": 0}
	return _data.levels[level_id]


static func _is_valid_nickname(value: String) -> bool:
	var trimmed := value.strip_edges()
	return not trimmed.is_empty() and trimmed.length() <= MAX_NICKNAME_LENGTH


static func _normalized(src: Dictionary) -> Dictionary:
	var out := {
		"schemaVersion": SCHEMA_VERSION,
		"guestId": _uuid_v4(),
		"profile": {},
		"seenIntro": false,
		"levels": {},
		"stats": {},
		"linkedProfileId": "",
	}
	var guest = src.get("guestId")
	if guest is String and guest.length() == 36:
		out.guestId = guest

	var p = src.get("profile")
	if p is Dictionary:
		if p.get("nickname") is String and _is_valid_nickname(p.nickname):
			out.profile.nickname = p.nickname
		if (p.get("grade") is float or p.get("grade") is int) and int(p.grade) in GRADES:
			out.profile.grade = int(p.grade)
		if p.get("character") is String and p.character in CHARACTER_IDS:
			out.profile.character = p.character

	if src.get("seenIntro") is bool:
		out.seenIntro = src.seenIntro
	var linked = src.get("linkedProfileId")
	if linked is String and (linked.is_empty() or linked.length() == 36):
		out.linkedProfileId = linked

	var levels = src.get("levels")
	if levels is Dictionary:
		for id in levels:
			var lv = levels[id]
			if not (id is String and lv is Dictionary):
				continue
			var collected: Array[String] = []
			if lv.get("collected") is Array:
				for item in lv.collected:
					if item is String and item not in collected:
						collected.append(item)
			var best = lv.get("battleStars")
			out.levels[id] = {
				"completed": lv.get("completed") is bool and lv.completed,
				"collected": collected,
				"battleStars": clampi(int(best), 0, 3) if _is_number(best) else 0,
			}

	var stats = src.get("stats")
	if stats is Dictionary:
		for topic in stats:
			var s = stats[topic]
			if topic is String and s is Dictionary and _is_number(s.get("attempts")) and _is_number(s.get("correct")):
				var attempts := maxi(int(s.attempts), 0)
				out.stats[topic] = {"attempts": attempts, "correct": clampi(int(s.correct), 0, attempts)}
	return out


static func _is_number(v: Variant) -> bool:
	return v is int or v is float


static func _uuid_v4() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
