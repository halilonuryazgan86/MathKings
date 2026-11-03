extends SceneTree
## Uçtan uca bulut testi: çalışan API'ye (Development) karşı gerçek HTTP istekleri.
## Önce: cd server && dotnet run --project src/MathKings.Api
## Çalıştırma: godot --headless --path game -s res://tools/e2e_cloud.gd
## Geliştiricinin yerel misafir kaydı ve oturumu yedeklenir, sonunda geri yüklenir.

const PASSWORD := "GucluSifre1"
const BACKUPS := ["user://save.json", "user://session.dat"]

var _passed := 0
var _failed := 0
var cloud: Node
var game: Node
var _base_url := "http://localhost:5055"


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  ok    ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _run() -> void:
	cloud = root.get_node("Cloud")
	game = root.get_node("GameState")
	# İsteğe bağlı: -- https://192.168.1.39:7258 (telefonun kullanacağı adres)
	if OS.get_cmdline_user_args().size() > 0:
		_base_url = OS.get_cmdline_user_args()[0]
		ProjectSettings.set_setting("mathkings/api/base_url", _base_url)
	_backup(true)
	await _scenario()
	await game.logout(false)
	_backup(false)
	print("\nE2E SONUÇ: %d geçti, %d başarısız" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _scenario() -> void:
	var health: Dictionary = await cloud._send(HTTPClient.METHOD_GET, "/health", null, false)
	check(health.ok, "API çalışıyor (%s)" % cloud.base_url())
	if not health.ok:
		return

	# 1) Misafir oyuncu çevrimdışı ilerler.
	await game.logout(false)
	var guest: SaveData = game.save
	guest.set_profile("Cesur Tilki", 5)
	guest.set_character("bora")
	guest.collect("forest_01", "coin_6_10")
	guest.collect("forest_01", "star_12_6")
	guest.record_battle("forest_01", 2)
	guest.complete_level("forest_01")
	game.persist()
	var guest_gold := guest.gold()

	# 2) Ebeveyn hesabı: kayıt, doğrulama öncesi giriş engeli, kodla doğrulama.
	var email := "e2e-%d@example.com" % Time.get_ticks_usec()
	check((await cloud.register(email, PASSWORD, true)).ok, "kayıt")
	var early: Dictionary = await cloud.login(email, PASSWORD)
	check(early.status == 403 and early.code == "email_not_confirmed", "doğrulanmamış e-posta ile giriş engellenir")
	var code_res: Dictionary = await cloud._send(HTTPClient.METHOD_GET,
		"/dev/last-code?kind=confirm&email=" + email.uri_encode(), null, false)
	if not code_res.ok:
		check(false, "doğrulama kodu alınamadı (durum %d)" % code_res.status)
		return
	check((await cloud.confirm_email(email, code_res.data.code)).ok, "e-posta 6 haneli kodla doğrulanır")
	check((await cloud.login(email, PASSWORD)).ok and cloud.is_logged_in(), "giriş")

	# 3) Misafir ilerlemesi hesaba aktarılır.
	var transfer: Dictionary = await game.transfer_guest_progress()
	check(transfer.ok and game.is_cloud_profile(), "misafir ilerlemesi yeni profile aktarıldı")
	check(game.save.gold() == guest_gold and game.save.nickname() == "Cesur Tilki", "aktarılan ilerleme ve profil korunur")
	var server_save: Dictionary = await cloud.get_save(cloud.active_profile_id)
	check(server_save.ok and int(server_save.data.gold) == guest_gold, "sunucudaki altın yerel altınla aynı (%d)" % guest_gold)
	check(not game.guest_save().linked_profile_id().is_empty(), "misafir kaydı aktarıldı olarak işaretlenir")

	# 4) Başka cihazdan gelen ilerleme senkronla birleşir.
	var other := SaveData.new()
	other.collect("forest_01", "coin_99_1")
	await cloud.put_save(cloud.active_profile_id, other.progress_dict())
	check(await game.sync_now() and game.save.gold() == guest_gold + 1, "ikinci cihazın altını kayıpsız birleşir")
	check(await game.sync_now() and game.save.gold() == guest_gold + 1, "tekrar senkron altını çoğaltmaz")

	# 5) Erişim belirteci reddedilirse otomatik yenilenir.
	cloud._access_token = "gecersiz"
	cloud._access_expires_at = Time.get_unix_time_from_system() + 3600
	check((await cloud.list_profiles()).ok, "reddedilen erişim belirteci otomatik yenilenir")

	# 6) Çevrimdışı: oyun çökmeden hata döner, oturum korunur.
	ProjectSettings.set_setting("mathkings/api/base_url", "http://127.0.0.1:9")
	cloud._access_token = ""
	var offline: Dictionary = await cloud.list_profiles()
	check(not offline.ok and offline.status == 0 and cloud.is_logged_in(), "çevrimdışıyken oturum korunur")
	game.save.collect("forest_01", "coin_7_10")
	game.persist()
	check(game.save.is_collected("forest_01", "coin_7_10"), "çevrimdışı ilerleme yerelde kaydedilir")
	ProjectSettings.set_setting("mathkings/api/base_url", _base_url)
	check(await game.sync_now(), "bağlantı gelince bekleyen ilerleme gönderilir")

	# 7) Oturum süresi dolunca güvenli davranış.
	var expired := [false]
	cloud.session_expired.connect(func() -> void: expired[0] = true, CONNECT_ONE_SHOT)
	cloud._access_token = ""
	cloud._refresh_token = "gecersiz-yenileme"
	var res: Dictionary = await cloud.list_profiles()
	check(not res.ok and expired[0] and not cloud.is_logged_in(), "geçersiz oturum kapatılır ve bildirilir")
	check(game.is_cloud_profile() and game.save.is_collected("forest_01", "coin_7_10"), "oturum düşse de yerel ilerleme kaybolmaz")

	# 8) Çıkış sunucuda yenileme belirtecini geçersiz kılar.
	check((await cloud.login(email, PASSWORD)).ok, "tekrar giriş")
	var old_refresh: String = cloud._refresh_token
	await game.logout()
	var reuse: Dictionary = await cloud._send(HTTPClient.METHOD_POST, "/api/v1/auth/refresh", {"refreshToken": old_refresh}, false)
	check(reuse.status == 401 and not game.is_cloud_profile(), "çıkıştan sonra eski belirteç çalışmaz, misafire dönülür")

	# 9) Hesap silme.
	var relogin: Dictionary = await cloud.login(email, PASSWORD)
	var deleted: Dictionary = await cloud.delete_account(PASSWORD)
	check(deleted.ok and not cloud.is_logged_in(),
		"hesap silinir (giriş %d, silme %d %s)" % [relogin.status, deleted.status, deleted.error])
	check((await cloud.login(email, PASSWORD)).status == 401, "silinen hesapla giriş yapılamaz")


func _backup(save: bool) -> void:
	for path in BACKUPS:
		var bak: String = path + ".e2e_bak"
		if save:
			if FileAccess.file_exists(path):
				DirAccess.copy_absolute(path, bak)
		else:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
			if FileAccess.file_exists(bak):
				DirAccess.rename_absolute(bak, path)
