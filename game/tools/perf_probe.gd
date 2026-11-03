extends SceneTree
## Performans ölçümü (pencereli çalıştırın): her bölümde karakter 10 sn koşar/zıplar,
## V-Sync kapalıyken ortalama FPS, en kötü %1 ve en uzun kare süresi raporlanır.
## Çalıştırma: godot --path game -s res://tools/perf_probe.gd

const SECONDS := 10.0
const LEVELS := ["forest_01", "forest_02", "cave_01", "island_01"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var game = root.get_node("GameState")
	game.save.mark_intro_seen()
	print("bölüm        ort.FPS  %1-düşük  en uzun kare  draw call  nesne")
	for id in LEVELS:
		game.current_level_id = id
		change_scene_to_file("res://scenes/levels/level.tscn")
		for i in 30:
			await process_frame
		var times: Array[float] = []
		var t := 0.0
		var draw_calls := 0.0
		Input.action_press("move_right")
		var last := Time.get_ticks_usec()
		while t < SECONDS:
			if int(t * 2.0) % 3 == 0:
				Input.action_press("jump")
			else:
				Input.action_release("jump")
			await process_frame
			var now := Time.get_ticks_usec()
			var dt := (now - last) / 1_000_000.0
			last = now
			times.append(dt)
			t += dt
			draw_calls = maxf(draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		Input.action_release("move_right")
		Input.action_release("jump")
		times.sort()
		var avg := 0.0
		for x in times:
			avg += x
		avg /= times.size()
		var p99: float = times[int(times.size() * 0.99)]
		print("%-12s %7.0f  %8.0f  %9.1f ms  %9d  %5d" % [id, 1.0 / avg, 1.0 / p99, times[-1] * 1000.0,
			draw_calls, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	quit()
