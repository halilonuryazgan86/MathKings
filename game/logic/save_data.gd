class_name SaveData
extends RefCounted
## Oyuncunun cihazdaki kaydı: veri + kurallar. Dosya işlemi yapmaz (bkz. SaveStore).
## Dışarıdan gelen (bozuk/değiştirilmiş) veri her zaman normalize edilir.

const SCHEMA_VERSION := 1
const GRADES: Array[int] = [4, 5, 6, 7]
const CHARACTER_IDS: Array[String] = ["arin", "lina", "bora"]
const MAX_NICKNAME_LENGTH := 24
const STAR_PREFIX := "star_"

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

func gold() -> int:
	return _data.gold


## Bir toplanabiliri yalnızca ilk kez ödüllendirir. Tekrar oynamada false döner.
func collect(level_id: String, item_id: String, gold_value: int) -> bool:
	if level_id.is_empty() or item_id.is_empty() or is_collected(level_id, item_id):
		return false
	_level(level_id).collected.append(item_id)
	_data.gold += maxi(gold_value, 0)
	return true


func is_collected(level_id: String, item_id: String) -> bool:
	return _data.levels.has(level_id) and item_id in _data.levels[level_id].collected


func star_count(level_id: String) -> int:
	if not _data.levels.has(level_id):
		return 0
	return _data.levels[level_id].collected.filter(
		func(id: String) -> bool: return id.begins_with(STAR_PREFIX)).size()


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
		_data.levels[level_id] = {"completed": false, "collected": []}
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
		"gold": 0,
		"levels": {},
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
	if src.get("gold") is float or src.get("gold") is int:
		out.gold = maxi(int(src.gold), 0)

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
			out.levels[id] = {
				"completed": lv.get("completed") is bool and lv.completed,
				"collected": collected,
			}
	return out


static func _uuid_v4() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
