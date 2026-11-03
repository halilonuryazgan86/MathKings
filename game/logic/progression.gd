class_name Progression
extends RefCounted
## Bölüm kilitleri ve sınıf önerisi.
## - Dünya içindeki bölümler sırayla açılır.
## - İlk dünyanın ilk bölümü her zaman açıktır; diğer dünyaların ilk bölümü onu bitirince açılır.
## - Sınıf önerisi yalnızca bilgilendirmedir: hiçbir dünya zorunlu değildir, hiçbiri sınıf yüzünden kilitlenmez.


static func is_unlocked(save: SaveData, worlds: Array, level_id: String) -> bool:
	var first := first_level_id(worlds)
	for world in worlds:
		var levels: Array = world.get("levels", [])
		for i in levels.size():
			if levels[i].id != level_id:
				continue
			if i > 0:
				return save.is_level_completed(levels[i - 1].id)
			return level_id == first or save.is_level_completed(first)
	return false


static func is_recommended(world: Dictionary, grade: int) -> bool:
	for g in world.get("grades", []):
		if int(g) == grade:
			return true
	return false


static func first_level_id(worlds: Array) -> String:
	for world in worlds:
		var levels: Array = world.get("levels", [])
		if not levels.is_empty():
			return levels[0].id
	return ""


## Aynı dünyadaki sonraki bölüm; yoksa boş.
static func next_level_id(worlds: Array, level_id: String) -> String:
	for world in worlds:
		var levels: Array = world.get("levels", [])
		for i in levels.size():
			if levels[i].id == level_id:
				return levels[i + 1].id if i + 1 < levels.size() else ""
	return ""
