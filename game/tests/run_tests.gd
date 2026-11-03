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
		test_generated_questions_are_correct,
		test_generator_is_deterministic,
		test_grade_topics,
		test_battle_rules,
		test_battle_stars,
		test_battle_reward_not_farmable,
		test_answer_stats,
		test_gold_matches_server_formula,
		test_merge_progress,
		test_progress_dict_has_no_personal_data,
		test_session_store_is_encrypted,
		test_cloud_error_messages,
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
	check(s.collect("forest_01", "coin_1_1"), "ilk toplama ödüllendirilir")
	check(not s.collect("forest_01", "coin_1_1"), "aynı altın tekrar ödüllendirilmez")
	check(s.gold() == 1, "altın yalnızca bir kez eklenir")
	check(s.collect("forest_01", "star_5_5"), "yıldız toplanır")
	check(s.star_count("forest_01") == 1, "yıldız sayısı doğru")
	check(s.collect("forest_02", "coin_1_1"), "farklı bölümde aynı id ayrı sayılır")
	check(not s.collect("forest_01", "hile_1") and s.gold() == 12, "bilinmeyen öğe ödül vermez; altın 1+10+1")


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
	s.collect("forest_01", "coin_3_10")
	s.complete_level("forest_01")
	s.mark_intro_seen()
	check(SaveStore.save_data(s, TEST_PATH), "kayıt yazıldı")
	check(not FileAccess.file_exists(TEST_PATH + ".tmp"), "geçici dosya kalmadı")
	var l := SaveStore.load_data(TEST_PATH)
	check(l.guest_id() == s.guest_id(), "misafir kimliği korunur")
	check(l.nickname() == "Zeki Panda" and l.grade() == 6 and l.character() == "bora", "profil korunur")
	check(l.gold() == 1 and l.is_collected("forest_01", "coin_3_10"), "ilerleme korunur")
	check(l.is_level_completed("forest_01") and l.seen_intro(), "bölüm ve tanıtım durumu korunur")
	check(not l.collect("forest_01", "coin_3_10"), "yeniden açılışta tekrar ödül yok")


func test_corrupt_file_recovers() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{bozuk json")
	f.close()
	var l := SaveStore.load_data(TEST_PATH)
	check(not l.has_profile() and l.gold() == 0, "bozuk kayıtta yeni kayıt açılır")
	check(FileAccess.file_exists(TEST_PATH + ".corrupt"), "bozuk dosya yedeklenir")


func test_interrupted_write_recovers() -> void:
	var s := SaveData.new()
	s.collect("forest_01", "coin_9_9")
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


# --- Matematik Savaşı --------------------------------------------------------

func _evaluate(expression: String) -> Variant:
	var e := Expression.new()
	if e.parse(expression.replace("×", "*").replace("÷", "/")) != OK:
		return null
	return e.execute()


func test_generated_questions_are_correct() -> void:
	TranslationServer.set_locale("tr")
	for grade in SaveData.GRADES:
		var gen := QuestionGenerator.for_grade(grade, QuestionGenerator.DEFAULT_PATH, 1000 + grade)
		var bad := []
		for i in 500:
			var q := gen.next()
			var value = _evaluate(q.expression)
			var hint := q.hint_text()
			var problems := []
			if not (value is int) or value != q.answer:
				problems.append("cevap %s != %s" % [q.answer, value])
			if q.answer < 0:
				problems.append("negatif cevap")
			if q.choices.size() != 4 or q.answer not in q.choices:
				problems.append("seçenekler")
			var unique := {}
			for c in q.choices:
				unique[c] = true
				if c < 0:
					problems.append("negatif seçenek")
			if unique.size() != 4:
				problems.append("tekrarlı seçenek")
			if hint == q.hint_key or "{" in hint:
				problems.append("ipucu çevirisi/parametresi eksik: " + hint)
			if not problems.is_empty():
				bad.append("%s -> %s" % [q.expression, problems])
		check(bad.is_empty(), "%d. sınıf: 500 soru doğru, 4 benzersiz seçenek, ipucu tam %s" % [grade, bad.slice(0, 3)])


func test_generator_is_deterministic() -> void:
	var a := QuestionGenerator.for_grade(5, QuestionGenerator.DEFAULT_PATH, 42)
	var b := QuestionGenerator.for_grade(5, QuestionGenerator.DEFAULT_PATH, 42)
	var same := true
	for i in 50:
		var qa := a.next()
		var qb := b.next()
		same = same and qa.expression == qb.expression and qa.choices == qb.choices
	check(same, "aynı seed aynı soru dizisini üretir")
	check(QuestionGenerator.for_grade(2).next() != null and QuestionGenerator.for_grade(9).next() != null,
		"aralık dışı sınıf güvenli şekilde sınırlanır")


func test_grade_topics() -> void:
	var topics := {}
	var gen := QuestionGenerator.for_grade(4, QuestionGenerator.DEFAULT_PATH, 3)
	for i in 300:
		topics[gen.next().topic] = true
	check(topics.keys().all(func(t: String) -> bool: return t in ["add", "sub", "mul", "div"]),
		"4. sınıfa işlem önceliği sorulmaz")
	topics.clear()
	gen = QuestionGenerator.for_grade(7, QuestionGenerator.DEFAULT_PATH, 3)
	for i in 300:
		topics[gen.next().topic] = true
	check(topics.has("order_paren") and topics.has("order_mix"), "7. sınıfta işlem önceliği soruları var")


func _question(answer: int) -> MathQuestion:
	var q := MathQuestion.new()
	q.answer = answer
	q.choices = [answer, answer + 1, answer + 2, answer + 3]
	return q


func test_battle_rules() -> void:
	var b := BattleState.new()
	b.start_question(_question(10))
	check(b.answer(11) == BattleState.Result.WRONG_HINT, "ilk yanlışta ipucu")
	check(b.monster_hp == BattleState.MONSTER_HP, "yanlış cevap canavara hasar vermez")
	check(b.answer(12) == BattleState.Result.WRONG_REVEAL, "ikinci yanlışta çözüm gösterilir")
	b.start_question(_question(7))
	check(b.answer(8) == BattleState.Result.WRONG_HINT and b.answer(7) == BattleState.Result.CORRECT,
		"ipucundan sonra doğru cevap kabul edilir")
	check(b.monster_hp == BattleState.MONSTER_HP - 1, "doğru cevap 1 hasar verir")
	check(not b.is_won(), "1 doğru cevapla savaş bitmez")
	for i in BattleState.MONSTER_HP - 1:
		b.start_question(_question(i))
		b.answer(i)
	check(b.is_won() and b.monster_hp == 0, "5 doğru cevapla savaş kazanılır")


func test_battle_stars() -> void:
	var perfect := BattleState.new()
	for i in 5:
		perfect.start_question(_question(i))
		perfect.answer(i)
	check(perfect.stars() == 3, "hepsi ilk denemede doğru: 3 yıldız")
	var struggled := BattleState.new()
	for i in 5:
		struggled.start_question(_question(i))
		struggled.answer(i + 1)
		struggled.answer(i)
	check(struggled.stars() == 1, "hepsi ipucuyla doğru: yine de 1 yıldız (kazanan herkes ödül alır)")


func test_battle_reward_not_farmable() -> void:
	var s := SaveData.new()
	check(s.record_battle("forest_01", 1) == 25, "ilk zafer: 20 + 1 yıldız × 5 = 25 altın")
	check(s.record_battle("forest_01", 1) == 0, "aynı sonuçla tekrar: altın yok")
	check(s.record_battle("forest_01", 3) == 10, "yıldız artışı: yalnızca yeni 2 yıldız için 10 altın")
	check(s.record_battle("forest_01", 2) == 0, "daha düşük sonuç: altın yok, rekor korunur")
	check(s.battle_stars("forest_01") == 3 and s.gold() == 35, "en iyi yıldız 3, toplam 35 altın")
	check(s.record_battle("forest_01", 99) == 0, "geçersiz yıldız değeri sınırlanır")
	var l := SaveData.new({"levels": {"forest_01": {"battleStars": 9, "collected": []}}})
	check(l.battle_stars("forest_01") == 3, "kayıttaki geçersiz savaş yıldızı sınırlanır")


func test_answer_stats() -> void:
	var s := SaveData.new()
	s.record_answer("mul", true)
	s.record_answer("mul", false)
	s.record_answer("div", true)
	check(s.topic_stats("mul") == {"attempts": 2, "correct": 1}, "konu istatistiği tutulur")
	SaveStore.save_data(s, TEST_PATH)
	check(SaveStore.load_data(TEST_PATH).topic_stats("div") == {"attempts": 1, "correct": 1}, "istatistik kaydedilir")
	var t := SaveData.new({"stats": {"mul": {"attempts": 2, "correct": 50}, "x": "bozuk"}})
	check(t.topic_stats("mul").correct == 2 and t.topic_stats("x").attempts == 0, "bozuk istatistik temizlenir")


# --- Bulut senkronizasyonu ---------------------------------------------------

func test_gold_matches_server_formula() -> void:
	# Sunucudaki ProgressRulesTests.Gold_matches_client_formula ile aynı örnek: 2 + 10 + 20 + 15.
	var s := SaveData.new({"levels": {"forest_01": {
		"completed": true, "battleStars": 3, "collected": ["coin_1_1", "coin_2_1", "star_3_1"]}}})
	check(s.gold() == 47, "altın formülü sunucuyla aynı (47)")


func test_merge_progress() -> void:
	var a := SaveData.new()
	a.collect("forest_01", "coin_1_1")
	a.collect("forest_01", "star_3_1")
	a.record_battle("forest_01", 1)
	a.complete_level("forest_01")
	a.record_answer("mul", true)
	var b := SaveData.new()
	b.collect("forest_01", "coin_1_1")
	b.collect("forest_01", "coin_9_9")
	b.record_battle("forest_01", 3)
	b.mark_intro_seen()
	b.record_answer("mul", false)
	b.record_answer("mul", false)

	a.merge_progress(b.progress_dict())
	check(a.to_dict().levels.forest_01.collected.size() == 3, "toplananlar birleşir, ortaklar tekrarlanmaz")
	check(a.battle_stars("forest_01") == 3 and a.is_level_completed("forest_01"), "en iyi savaş ve tamamlanma korunur")
	check(a.seen_intro(), "tanıtım durumu birleşir")
	check(a.topic_stats("mul") == {"attempts": 2, "correct": 1}, "istatistik en büyük değerlerle birleşir")
	var gold := a.gold()
	a.merge_progress(b.progress_dict())
	check(a.gold() == gold and gold == 1 + 1 + 10 + 20 + 15, "tekrar birleştirme altını artırmaz")
	a.merge_progress({"levels": {"forest_01": {"battleStars": 99, "collected": ["hile"]}}, "stats": "bozuk"})
	check(a.battle_stars("forest_01") == 3 and a.gold() == gold, "bozuk sunucu verisi normalize edilir")


func test_progress_dict_has_no_personal_data() -> void:
	var s := SaveData.new()
	s.set_profile("Cesur Tilki", 5)
	var keys := s.progress_dict().keys()
	keys.sort()
	check(keys == ["levels", "seenIntro", "stats"], "sunucuya yalnızca ilerleme gider (takma ad ve misafir kimliği gitmez)")


func test_session_store_is_encrypted() -> void:
	var path := "user://test_session.dat"
	SessionStore.write({"email": "veli@example.com", "refreshToken": "gizli-belirtec"}, path)
	var raw := FileAccess.get_file_as_bytes(path).get_string_from_ascii()
	check(not "gizli-belirtec" in raw, "yenileme belirteci dosyada düz metin değil")
	check(SessionStore.read(path).get("refreshToken") == "gizli-belirtec", "oturum geri okunur")
	check(SessionStore.read(path, "baska-anahtar").is_empty(), "başka cihaz anahtarıyla okunamaz")
	SessionStore.clear(path)
	check(SessionStore.read(path).is_empty(), "oturum silinir")


func test_cloud_error_messages() -> void:
	TranslationServer.set_locale("tr")
	# Autoload sınıfı -s modunda derleme anında yok; betiği doğrudan yükle.
	var cloud: GDScript = load("res://autoload/cloud.gd")
	check(cloud.error_message(0, null) == TranslationServer.translate("NET_OFFLINE"), "bağlantı yok mesajı")
	check(cloud.error_message(400, {"errors": {"password": ["Şifre en az 8 karakter olmalı."]}}) == "Şifre en az 8 karakter olmalı.",
		"sunucu doğrulama mesajı gösterilir")
	check(cloud.error_message(401, {"detail": "E-posta veya şifre hatalı."}) == "E-posta veya şifre hatalı.", "sunucu detay mesajı")
	check(cloud.error_message(401, null, "SESSION_EXPIRED") == TranslationServer.translate("SESSION_EXPIRED"), "oturum süresi doldu mesajı")


func test_translations() -> void:
	TranslationServer.set_locale("tr")
	check(TranslationServer.translate("GAME_TITLE") == "Matematik Krallığı", "Türkçe çeviri yüklü")
