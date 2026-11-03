extends Node
## Aktif oyuncu kaydı (misafir veya hesaba bağlı profil), içerik kataloğu ve sahne geçişleri.
## Oyun her zaman yerel kayıtla çalışır; hesaplı profilde değişiklikler arka planda senkronlanır.

signal gold_changed(total: int)

const WORLDS_PATH := "res://data/worlds.json"
const SCENE_MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const SCENE_PROFILE_SETUP := "res://scenes/menu/profile_setup.tscn"
const SCENE_CHARACTER_SELECT := "res://scenes/menu/character_select.tscn"
const SCENE_LEVEL := "res://scenes/levels/level.tscn"
const SCENE_PARENTAL_GATE := "res://scenes/account/parental_gate.tscn"
const SCENE_ACCOUNT := "res://scenes/account/account.tscn"
const SCENE_PROFILE_PICKER := "res://scenes/account/profile_picker.tscn"
const SCENE_WORLD_MAP := "res://scenes/menu/world_map.tscn"
const FIRST_LEVEL_ID := "forest_01"
const SYNC_DELAY_SEC := 2.0

var save: SaveData
var save_path := SaveStore.DEFAULT_PATH
var current_level_id := FIRST_LEVEL_ID
## Ekranlar arası küçük durumlar.
var notice_key := ""                 # Ana menüde bir kez gösterilecek bildirim
var account_mode := "login"          # Hesap ekranının açılış modu
var after_gate_scene := SCENE_ACCOUNT
var creating_cloud_profile := false  # Profil kurulumu hesaba yeni profil ekliyor
var _worlds: Array = []
var _levels := {}  # level_id -> level tanımı (worlds.json)
var _level_world := {}  # level_id -> dünya tanımı
var _sync_queued := false


## Masaüstünde telefon simülasyonu: godot --path game -- --mobile
## Dokunmatik butonlar görünür, fare tıklamaları dokunma olarak işlenir.
var mobile_sim := "--mobile" in OS.get_cmdline_user_args()


## Ekrandaki dokunmatik kontroller gösterilsin mi?
func is_touch_ui() -> bool:
	return mobile_sim or DisplayServer.is_touchscreen_available()


func _ready() -> void:
	TranslationServer.set_locale("tr")
	if mobile_sim:
		Input.emulate_touch_from_mouse = true
	_load_worlds()
	Cloud.session_expired.connect(func() -> void: notice_key = "SESSION_EXPIRED")
	if Cloud.active_profile_id.is_empty():
		_use_save(SaveStore.DEFAULT_PATH)
	else:
		_use_save(cloud_save_path(Cloud.active_profile_id))
		sync_now.call_deferred()


func persist() -> void:
	SaveStore.save_data(save, save_path)
	if is_cloud_profile() and Cloud.is_logged_in():
		_queue_sync()


## Toplanabiliri kaydeder. İlk kez toplanmışsa true.
func collect(level_id: String, item_id: String) -> bool:
	if not save.collect(level_id, item_id):
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


# --- Hesap ve profiller ------------------------------------------------------

func is_cloud_profile() -> bool:
	return save_path != SaveStore.DEFAULT_PATH


static func cloud_save_path(profile_id: String) -> String:
	return "user://cloud_%s.json" % profile_id


func guest_save() -> SaveData:
	return save if not is_cloud_profile() else SaveStore.load_data(SaveStore.DEFAULT_PATH)


## Hesaptaki bir profile geçer: yerel kopyayı yükler, sunucudakiyle birleştirir ve gönderir.
func activate_cloud_profile(profile: Dictionary, extra_progress := {}) -> void:
	Cloud.set_active_profile(profile.id)
	_use_save(cloud_save_path(profile.id))
	save.set_profile(profile.nickname, int(profile.grade))
	save.set_character(profile.characterId)
	if not extra_progress.is_empty():
		save.merge_progress(extra_progress)
	var res := await Cloud.get_save(profile.id)
	if res.ok:
		save.merge_progress(res.data.progress)
	SaveStore.save_data(save, save_path)
	await sync_now()


## Bu cihazdaki misafir ilerlemesini hesaba yeni profil olarak aktarır.
func transfer_guest_progress() -> Dictionary:
	var guest := SaveStore.load_data(SaveStore.DEFAULT_PATH)
	var res := await Cloud.create_profile(guest.nickname(), guest.grade(), guest.character())
	if not res.ok:
		return res
	guest.set_linked_profile_id(res.data.id)
	SaveStore.save_data(guest, SaveStore.DEFAULT_PATH)
	await activate_cloud_profile(res.data, guest.progress_dict())
	return res


## Profil adı/sınıfı/karakteri değiştiyse sunucuya bildir (başarısızsa sonraki seçimde düzelir).
func push_profile_details() -> void:
	if is_cloud_profile() and Cloud.is_logged_in():
		await Cloud.update_profile(Cloud.active_profile_id, save.nickname(), save.grade(), save.character())


func use_guest() -> void:
	Cloud.set_active_profile("")
	_use_save(SaveStore.DEFAULT_PATH)


## Hesaptan çıkış: sunucuda oturumu kapatır, bu cihazdaki hesap kopyalarını siler.
func logout(call_server := true) -> void:
	if call_server:
		await Cloud.logout()
	use_guest()
	for file in DirAccess.get_files_at("user://"):
		if file.begins_with("cloud_"):
			DirAccess.remove_absolute("user://" + file)


## Yerel ilerlemeyi sunucuya gönderir ve birleşik sonucu geri alır.
func sync_now() -> bool:
	if not (is_cloud_profile() and Cloud.is_logged_in()):
		return false
	var profile_id := Cloud.active_profile_id
	var res := await Cloud.put_save(profile_id, save.progress_dict())
	if not res.ok or profile_id != Cloud.active_profile_id:
		return false
	save.merge_progress(res.data.progress)
	SaveStore.save_data(save, save_path)
	gold_changed.emit(save.gold())
	return true


func _queue_sync() -> void:
	if _sync_queued:
		return
	_sync_queued = true
	await get_tree().create_timer(SYNC_DELAY_SEC).timeout
	_sync_queued = false
	await sync_now()


func _use_save(path: String) -> void:
	save_path = path
	save = SaveStore.load_data(path)
	gold_changed.emit(save.gold())


# --- İçerik ve sahneler ------------------------------------------------------

func level_layout_path(level_id: String) -> String:
	return _levels.get(level_id, {}).get("layout", "")


func worlds() -> Array:
	return _worlds


func world_for_level(level_id: String) -> Dictionary:
	return _level_world.get(level_id, {})


func level_name(level_id: String) -> String:
	return tr(_levels.get(level_id, {}).get("nameKey", level_id))


func is_level_unlocked(level_id: String) -> bool:
	return Progression.is_unlocked(save, _worlds, level_id)


## Sonraki bölüm (aynı dünyada ve açıksa); yoksa boş.
func next_unlocked_level(level_id: String) -> String:
	var next := Progression.next_level_id(_worlds, level_id)
	return next if not next.is_empty() and is_level_unlocked(next) else ""


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
				SaveStore.save_data(save, save_path)
				if is_cloud_profile() and Cloud.is_logged_in():
					sync_now()
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
	_worlds = parsed.worlds
	for world in _worlds:
		for level in world.get("levels", []):
			_levels[level.id] = level
			_level_world[level.id] = world
