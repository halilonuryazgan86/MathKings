class_name LevelLayout
extends RefCounted
## Metin tabanlı bölüm haritası. Dosya "---" satırlarıyla ayrılmış parçalardan oluşur;
## her parçanın satırları kendi genişliğine tamamlanır ve parçalar yan yana eklenir.
##
## Lejant:
##   .  boş          #  zemin          =  tek yönlü platform
##   c  altın        s  yıldız         ^  diken (tehlike)
##   C  kontrol nok. P  başlangıç      G  Kristal Kapısı

const EMPTY := "."
const SEPARATOR := "---"


static func parse(text: String) -> PackedStringArray:
	var segments: Array[PackedStringArray] = [PackedStringArray()]
	for raw_line in text.replace("\r", "").split("\n"):
		var line := raw_line.strip_edges(false, true)
		if line == SEPARATOR:
			segments.append(PackedStringArray())
		elif not line.is_empty() and not line.begins_with(";"):
			segments[-1].append(line)

	var height := 0
	for seg in segments:
		height = maxi(height, seg.size())

	var rows := PackedStringArray()
	rows.resize(height)
	rows.fill("")
	for seg in segments:
		var width := 0
		for line in seg:
			width = maxi(width, line.length())
		# Kısa parçalar üstten boşlukla tamamlanır (zemin hep altta kalır).
		var offset := height - seg.size()
		for y in height:
			var line := seg[y - offset] if y >= offset else ""
			rows[y] += line.rpad(width, EMPTY)
	return rows


static func load_file(path: String) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		push_error("Bölüm dosyası bulunamadı: %s" % path)
		return PackedStringArray()
	return parse(FileAccess.get_file_as_string(path))
