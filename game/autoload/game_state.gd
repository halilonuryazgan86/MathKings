extends Node
## Aktif oyuncu kaydı, içerik kataloğu ve sahne geçişleri.

signal gold_changed(total: int)

const WORLDS_PATH := "res://data/worlds.json"
const SCENE_MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const SCENE_PROFILE_SETUP := "res://scenes/menu/profile_setup.tscn"
const SCENE_CHARACTER_SELECT := "res://scenes/menu/character_select.tscn"
const SCENE_LEVEL := "res://scenes/levels/level.tscn"
const FIRST_LEVEL_ID := "forest_01"

var save: SaveData
var current_level_id := FIRST_LEVEL_ID
var _levels := {}  # level_id -> level tanımı (worlds.json)


func _ready() -> void:
	TranslationServer.set_locale("tr")
	save = SaveStore.load_data()
	_load_worlds()


func persist() -> void:
	SaveStore.save_data(save)


## Toplanabiliri ödüllendirir ve hemen kaydeder. İlk kez toplanmışsa true.
func collect(level_id: String, item_id: String, gold_value: int) -> bool:
	if not save.collect(level_id, item_id, gold_value):
		return false
	persist()
	gold_changed.emit(save.gold())
	return true


## Savaş sonucunu ve bölüm tamamlanmasını kaydeder; verilen altını döndürür.
func finish_battle(level_id: String, stars: int) -> int:
	var reward := save.record_battle(level_id, stars)
	save.complete_level(level_id)
	persist()
	gold_changed.emit(save.gold())
	return reward


func level_layout_path(level_id: String) -> String:
	return _levels.get(level_id, {}).get("layout", "")


func start_level(level_id: String) -> void:
	current_level_id = level_id
	go_to(SCENE_LEVEL)


func go_to(scene_path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			# Android'de uygulama arka plana alındığında veya kapatıldığında kaydet.
			if save != null:
				persist()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android geri tuşu: her ekran ui_cancel'ı kendi bağlamında işler.
			var ev := InputEventAction.new()
			ev.action = "ui_cancel"
			ev.pressed = true
			Input.parse_input_event(ev)


func _load_worlds() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(WORLDS_PATH))
	if not (parsed is Dictionary and parsed.get("worlds") is Array):
		push_error("İçerik kataloğu okunamadı: %s" % WORLDS_PATH)
		return
	for world in parsed.worlds:
		for level in world.get("levels", []):
			_levels[level.id] = level
