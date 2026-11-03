extends SceneTree
## Geliştirici aracı: ekranların görüntüsünü alır (görsel kontrol için).
## Çalıştırma (pencereli): godot --path game -s res://tools/capture_screens.gd -- <çıktı klasörü>

const SHOTS := [
	["main_menu", "res://scenes/menu/main_menu.tscn", []],
	["profile_setup", "res://scenes/menu/profile_setup.tscn", []],
	["character_select", "res://scenes/menu/character_select.tscn", []],
	["level", "res://scenes/levels/level.tscn", [200.0, 2400.0, 4300.0, 7600.0, 9900.0, 13700.0]],
]

var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	for shot in SHOTS:
		change_scene_to_file(shot[1])
		await _frames(20)
		await _capture(shot[0])
		for x: float in shot[2]:
			var player := current_scene.get_node("Player") as Node2D
			paused = false
			current_scene.get_node("OwlDialog/Root").hide()
			player.global_position = Vector2(x, 0)
			await _frames(90)
			await _capture("%s_%d" % [shot[0], int(x)])
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("yakalandı: ", path)
