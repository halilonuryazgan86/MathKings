class_name SessionStore
extends RefCounted
## Hesap oturumu (e-posta, yenileme belirteci, aktif profil) cihaza şifreli kaydedilir.
## Erişim belirteci hiç diske yazılmaz. Anahtar cihaz kimliğinden türetilir; dosya Android
## uygulama alanındadır. Android Keystore eklentisi yayın öncesi değerlendirilecek.

const DEFAULT_PATH := "user://session.dat"


static func key() -> String:
	return ("mathkings-session-v1-" + OS.get_unique_id()).sha256_text()


static func write(data: Dictionary, path: String = DEFAULT_PATH, pass_key: String = key()) -> bool:
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, pass_key)
	if f == null:
		push_error("Oturum kaydedilemedi: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


static func read(path: String = DEFAULT_PATH, pass_key: String = key()) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, pass_key)
	if f == null:
		return {}  # Başka cihazdan kopyalanmış veya bozuk: oturum yok say.
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


static func clear(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
