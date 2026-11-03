extends Node
## Ses ayarları (cihaza özel, profil kaydından bağımsız).

const PATH := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var music_on := true
var sfx_on := true


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		var music = cfg.get_value("audio", "music", true)
		var sfx = cfg.get_value("audio", "sfx", true)
		music_on = music if music is bool else true
		sfx_on = sfx if sfx is bool else true
	_apply()


func set_music(on: bool) -> void:
	music_on = on
	_apply()
	_save()


func set_sfx(on: bool) -> void:
	sfx_on = on
	_apply()
	_save()


func _apply() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not sfx_on)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "sfx", sfx_on)
	cfg.save(PATH)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
