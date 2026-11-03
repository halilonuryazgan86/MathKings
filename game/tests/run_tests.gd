extends SceneTree
## Basit headless test koşucusu (ek bağımlılık yok).
## Çalıştırma: godot --headless --path game -s res://tests/run_tests.gd
## Çıkış kodu: başarısız test varsa 1.

const TEST_PATH := "user://test_save.json"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	var tests := [
		test_default_save,
		test_profile_validation,
		test_collect_only_once,
		test_complete_level_only_once,
		test_save_roundtrip,
		test_corrupt_file_recovers,
		test_interrupted_write_recovers,
		test_tampered_values_normalized,
		test_layout_parse,
		test_forest_01_layout,
		test_worlds_catalog,
		test_input_actions,
		test_translations,
	]
	for t: Callable in tests:
		_cleanup()
		t.call()
	_cleanup()
	print("\nSONUÇ: %d geçti, %d başarısız" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  ok    ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _cleanup() -> void:
	for suffix in ["", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)


# --- SaveData ----------------------------------------------------------------

func test_default_save() -> void:
	var s := SaveData.new()
	check(not s.has_profile(), "yeni kayıtta profil yok")
	check(s.gold() == 0, "yeni kayıtta altın 0")
	check(s.guest_id().length() == 36, "misafir kimliği UUID formatında")
	check(SaveData.new().guest_id() != s.guest_id(), "misafir kimlikleri benzersiz")


func test_profile_validation() -> void:
	var s := SaveData.new()
	check(not s.set_profile("", 5), "boş takma ad reddedilir")
	check(not s.set_profile("Cesur Tilki", 3), "geçersiz sınıf reddedilir")
	check(not s.set_profile("x".repeat(25), 5), "çok uzun takma ad reddedilir")
	check(s.set_profile("Cesur Tilki", 5), "geçerli profil kabul edilir")
	check(not s.has_profile(), "karakter seçilmeden profil tamamlanmaz")
	check(not s.set_character("ejderha"), "bilinmeyen karakter reddedilir")
	check(s.set_character("lina") and s.has_profile(), "karakter seçilince profil tamam")


func test_collect_only_once() -> void:
	var s := SaveData.new()
	check(s.collect("forest_01", "coin_1_1", 1), "ilk toplama ödüllendirilir")
	check(not s.collect("forest_01", "coin_1_1", 1), "aynı altın tekrar ödüllendirilmez")
	check(s.gold() == 1, "altın yalnızca bir kez eklenir")
	check(s.collect("forest_01", "star_5_5", 10), "yıldız toplanır")
	check(s.star_count("forest_01") == 1, "yıldız sayısı doğru")
	check(s.collect("forest_02", "coin_1_1", 1), "farklı bölümde aynı id ayrı sayılır")
	check(s.collect("forest_01", "coin_2_2", -50) and s.gold() == 12, "negatif ödül altını düşürmez")


func test_complete_level_only_once() -> void:
	var s := SaveData.new()
	check(s.complete_level("forest_01"), "ilk tamamlama true")
	check(not s.complete_level("forest_01"), "tekrar tamamlama false")
	check(s.is_level_completed("forest_01"), "bölüm tamamlandı olarak işaretli")


# --- SaveStore ---------------------------------------------------------------

func test_save_roundtrip() -> void:
	var s := SaveData.new()
	s.set_profile("Zeki Panda", 6)
	s.set_character("bora")
	s.collect("forest_01", "coin_3_10", 1)
	s.complete_level("forest_01")
	s.mark_intro_seen()
	check(SaveStore.save_data(s, TEST_PATH), "kayıt yazıldı")
	check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "geçici dosya kalmadı")
	var l := SaveStore.load_data(TEST_PATH)
	check(l.guest_id() == s.guest_id(), "misafir kimliği korunur")
	check(l.nickname() == "Zeki Panda" and l.grade() == 6 and l.character() == "bora", "profil korunur")
	check(l.gold() == 1 and l.is_collected("forest_01", "coin_3_10"), "ilerleme korunur")
	check(l.is_level_completed("forest_01") and l.seen_intro(), "bölüm ve tanıtım durumu korunur")
	check(not l.collect("forest_01", "coin_3_10", 1), "yeniden açılışta tekrar ödül yok")


func test_corrupt_file_recovers() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{bozuk json")
	f.close()
	var l := SaveStore.load_data(TEST_PATH)
	check(not l.has_profile() and l.gold() == 0, "bozuk kayıtta yeni kayıt açılır")
	check(FileAccess.file_exists(TEST_PATH + ".corrupt"), "bozuk dosya yedeklenir")


func test_interrupted_write_recovers() -> void:
	var s := SaveData.new()
	s.collect("forest_01", "coin_9_9", 1)
	var f := FileAccess.open(TEST_PATH + ".tmp", FileAccess.WRITE)
	f.store_string(JSON.stringify(s.to_dict()))
	f.close()
	var l := SaveStore.load_data(TEST_PATH)
	check(l.gold() == 1, "yarıda kalan yazmada geçici dosyadan kurtarılır")


func test_tampered_values_normalized() -> void:
	var l := SaveData.new({
		"gold": -999, "guestId": 5, "seenIntro": "evet",
		"profile": {"nickname": 42, "grade": 99, "character": "hile"},
		"levels": {"forest_01": {"completed": "true", "collected": ["a", "a", 7]}},
	})
	check(l.gold() == 0, "negatif altın sıfırlanır")
	check(l.guest_id().length() == 36, "geçersiz misafir kimliği yenilenir")
	check(not l.has_profile() and not l.seen_intro(), "geçersiz profil alanları atılır")
	check(not l.is_level_completed("forest_01"), "string 'true' tamamlanma sayılmaz")
	check(l.to_dict().levels.forest_01.collected == ["a"], "tekrarlı/geçersiz id'ler temizlenir")


# --- İçerik ve ayarlar -------------------------------------------------------

func test_layout_parse() -> void:
	var rows := LevelLayout.parse("; yorum\n..\n##\n---\n#\n")
	check(rows.size() == 2, "yükseklik en yüksek parçaya eşit")
	check(rows[0] == "...", "kısa parça üstten boşlukla tamamlanır")
	check(rows[1] == "###", "parçalar yan yana eklenir")


func test_forest_01_layout() -> void:
	var rows := LevelLayout.load_file("res://data/levels/forest_01.txt")
	var text := "\n".join(rows)
	check(rows.size() == 14, "orman haritası 14 satır")
	var same_width := true
	for r in rows:
		same_width = same_width and r.length() == rows[0].length()
	check(same_width, "tüm satırlar aynı genişlikte")
	check(text.count("P") == 1, "tek başlangıç noktası")
	check(text.count("G") == 1, "tek Kristal Kapısı")
	check(text.count("s") == 3, "3 yıldız")


func test_worlds_catalog() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/worlds.json"))
	check(parsed is Dictionary, "worlds.json okunur")
	var level: Dictionary = parsed.worlds[0].levels[0]
	check(parsed.worlds[0].isPremium == false, "ilk dünya ücretsiz")
	check(FileAccess.file_exists(level.layout), "bölüm haritası dosyası mevcut")


func test_input_actions() -> void:
	for action in ["move_left", "move_right", "jump"]:
		check(InputMap.has_action(action) and InputMap.action_get_events(action).size() >= 2,
			"girdi eylemi tanımlı: %s" % action)


func test_translations() -> void:
	TranslationServer.set_locale("tr")
	check(TranslationServer.translate("GAME_TITLE") == "Matematik Krallığı", "Türkçe çeviri yüklü")
