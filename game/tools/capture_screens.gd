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
	await _capture_battle()
	quit()


## Gerçek akış: oyuncu kapıya gider, Baykuş konuşur, savaş oynanır, sonuç ekranı gelir.
## (Tipsiz değişkenler: -s modunda autoload'lar derleme anında henüz kayıtlı değildir.)
func _capture_battle() -> void:
	var level = current_scene
	var gate: Node2D = level.get_node("Objects").get_children().filter(
		func(n: Node) -> bool: return n is CrystalGate)[0]
	paused = false
	level.get_node("Player").global_position = gate.global_position + Vector2(-60, -10)
	await _frames(30)
	var owl = level.get_node("OwlDialog")
	while owl.is_open():
		owl.get_node("%NextButton").pressed.emit()
		await _frames(5)

	var battle = level.get_node("MathBattle")
	await _frames(30)
	await _capture("battle_start")
	var buttons: Array = battle.get_node("%Answers").get_children()
	var answer: int = battle._state.current.answer
	var wrong := buttons.filter(func(b: Button) -> bool: return b.get_meta("value") != answer)
	wrong[0].pressed.emit()
	await _frames(30)
	await _capture("battle_hint")
	wrong[1].pressed.emit()
	await _frames(30)
	await _capture("battle_reveal")
	battle.get_node("%ContinueButton").pressed.emit()
	for i in BattleState.MONSTER_HP:
		while battle._busy:
			await _frames(2)
		answer = battle._state.current.answer
		buttons.filter(func(b: Button) -> bool: return b.get_meta("value") == answer)[0].pressed.emit()
		await _frames(30)
		if i == 0:
			await _capture("battle_attack")
	while battle._question.text.ends_with("?"):
		await _frames(2)
	await _frames(50)
	await _capture("battle_victory")
	while battle.is_open():
		await _frames(5)
	await _frames(30)
	await _capture("level_result")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("yakalandı: ", path)
