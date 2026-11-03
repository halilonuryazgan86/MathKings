class_name MusicSynth
extends RefCounted
## Kodla üretilen özgün, sakin müzik döngüleri (telif riski yok; nihai müzik gelene kadar).
## Melodi pentatonik dizi derecelerinden, bas akor köklerinden üretilir. Sonuç döngülü WAV'dır.

const RATE := 22050

## Her parça: tempo, ana nota (MIDI), dizi, akor kökleri (yarım ton, ölçü başına), melodi (8'lik notalar, -1 = es).
const TRACKS := {
	"menu": {"bpm": 96, "root": 67, "scale": [0, 2, 4, 7, 9], "chords": [0, -3, 5, 7],
		"melody": [0, -1, 2, 4, 2, -1, 1, 0, 2, 3, 4, -1, 3, 2, 1, -1, 0, 2, 4, 5, 4, 2, 3, -1, 2, 1, 0, -1, 0, -1, -1, -1]},
	"forest": {"bpm": 112, "root": 67, "scale": [0, 2, 4, 7, 9], "chords": [0, 5, -3, 7],
		"melody": [0, 2, 4, 2, 3, 4, 5, -1, 4, 3, 2, 0, 1, 2, 0, -1, 0, 2, 4, 5, 6, 5, 4, -1, 3, 2, 1, 2, 0, -1, 0, -1]},
	"cave": {"bpm": 96, "root": 62, "scale": [0, 3, 5, 7, 10], "chords": [0, -2, -4, -2],
		"melody": [0, -1, 2, -1, 3, 2, 0, -1, 1, -1, 2, 3, 4, -1, 3, -1, 2, -1, 0, -1, 1, 2, 1, -1, 0, -1, -1, 3, 2, -1, -1, -1]},
	"island": {"bpm": 116, "root": 65, "scale": [0, 2, 4, 7, 9], "chords": [0, 5, 7, 5],
		"melody": [4, 3, 2, -1, 2, 3, 4, 5, 4, -1, 2, 0, 1, -1, 2, -1, 4, 5, 6, 5, 4, 2, 3, -1, 2, 1, 0, 1, 2, -1, 0, -1]},
	"battle": {"bpm": 138, "root": 64, "scale": [0, 2, 3, 7, 9], "chords": [0, 0, -4, -2],
		"melody": [0, 0, 2, 0, 3, 2, 0, -1, 0, 0, 2, 3, 4, 3, 2, -1, 4, 4, 3, 2, 3, 2, 0, -1, 1, 2, 3, 2, 0, -1, 0, -1]},
}


static func render(track: String) -> AudioStreamWAV:
	var spec: Dictionary = TRACKS.get(track, TRACKS.menu)
	var beat := 60.0 / float(spec.bpm)
	var eighth := beat / 2.0
	var melody: Array = spec.melody
	var bars := melody.size() / 8
	var n := int(bars * 4 * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)

	# Melodi: yumuşak kare dalga (%25 doluluk), kısa sönümlü zarf.
	for i in melody.size():
		var degree: int = melody[i]
		if degree < 0:
			continue
		var scale: Array = spec.scale
		var midi: int = spec.root + scale[degree % scale.size()] + 12 * (degree / scale.size())
		_add_note(buf, int(i * eighth * RATE), int(eighth * 0.9 * RATE), _hz(midi), 0.11, true)

	# Bas: her vuruşta akor kökü, üçgen dalga.
	var chords: Array = spec.chords
	for b in bars * 4:
		var root: int = spec.root - 24 + int(chords[(b / 4) % chords.size()])
		_add_note(buf, int(b * beat * RATE), int(beat * 0.8 * RATE), _hz(root), 0.16, false)

	# Hafif zil: ara vuruşlarda kısa gürültü.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for b in bars * 4:
		var start := int((b + 0.5) * beat * RATE)
		for k in int(0.03 * RATE):
			if start + k < n:
				buf[start + k] += rng.randf_range(-1.0, 1.0) * 0.025 * (1.0 - k / (0.03 * RATE))

	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav


static func _add_note(buf: PackedFloat32Array, start: int, length: int, freq: float, amp: float, square: bool) -> void:
	var attack := 0.01 * RATE
	for k in length:
		var idx := start + k
		if idx >= buf.size():
			return
		var phase := fmod(k * freq / RATE, 1.0)
		var wave := (1.0 if phase < 0.25 else -0.6) if square else (4.0 * absf(phase - 0.5) - 1.0)
		var env := minf(1.0, k / attack) * exp(-3.0 * k / float(length))
		buf[idx] += wave * amp * env


static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)
