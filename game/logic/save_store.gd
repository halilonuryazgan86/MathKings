class_name SaveStore
extends RefCounted
## Kayıt dosyası okuma/yazma. Önce geçici dosyaya yazar; bozuk dosyayı yedekleyip
## oyunu çökertmeden yeni kayıtla devam eder.

const DEFAULT_PATH := "user://save.json"


static func load_data(path: String = DEFAULT_PATH) -> SaveData:
	var source := path
	if not FileAccess.file_exists(source):
		# Yazma sırasında kesilmiş olabilir: geçici dosya varsa onu kullan.
		source = path + ".tmp"
		if not FileAccess.file_exists(source):
			return SaveData.new()

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(source))
	if parsed is Dictionary:
		return SaveData.new(parsed)

	push_warning("Kayıt okunamadı, yedeklenip yeni kayıt açılıyor: %s" % source)
	DirAccess.rename_absolute(source, path + ".corrupt")
	return SaveData.new()


static func save_data(save: SaveData, path: String = DEFAULT_PATH) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Kayıt yazılamadı (%s): %s" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(save.to_dict(), "\t"))
	file.close()

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("Kayıt taşınamadı: %s" % error_string(err))
		return false
	return true
