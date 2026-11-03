class_name Sfx
extends RefCounted
## Kodla üretilen kısa, yumuşak ses efektleri (nihai sesler gelene kadar).
## "SFX" bus'ında çalar; Ayarlar'dan kapatılabilir.

const RATE := 22050
const SOUNDS := {
	"coin": [[1320.0, 0.05], [1760.0, 0.08]],
	"correct": [[660.0, 0.08], [880.0, 0.08], [1320.0, 0.16]],
	"wrong": [[392.0, 0.12], [330.0, 0.18]],
	"hit": [[220.0, 0.06], [165.0, 0.08]],
	"win": [[523.0, 0.12], [659.0, 0.12], [784.0, 0.12], [1047.0, 0.3]],
}

static var _cache := {}


static func play(context: Node, sound: String) -> void:
	if not SOUNDS.has(sound) or not context.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.stream = _stream(sound)
	player.bus = Settings.SFX_BUS
	player.volume_db = -6.0
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	context.get_tree().root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var data := PackedByteArray()
	for note in SOUNDS[sound]:
		var freq: float = note[0]
		var n := int(RATE * note[1])
		for i in n:
			var attack := minf(1.0, i / (RATE * 0.004))
			var env := attack * pow(1.0 - float(i) / n, 1.5)
			var s := sin(TAU * freq * i / RATE) * 0.8 + sin(TAU * freq * 2.0 * i / RATE) * 0.2
			var v := int(s * env * 0.45 * 32767.0)
			data.append(v & 0xff)
			data.append((v >> 8) & 0xff)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	_cache[sound] = wav
	return wav
