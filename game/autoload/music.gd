extends Node
## Arka plan müziği. Parçalar ilk istendiğinde arka plan iş parçacığında üretilir ve önbelleğe alınır;
## geçişlerde yumuşak ses kısma/açma yapılır. "Music" bus'ı Ayarlar'dan kapatılabilir.

const VOLUME_DB := -12.0
const FADE_SEC := 0.6

var _player := AudioStreamPlayer.new()
var _current := ""
var _cache := {}
var _tasks := {}    # parça -> WorkerThreadPool görev kimliği
var _results := {}  # iş parçacığının ürettiği parçalar (yalnızca _mutex ile)
var _mutex := Mutex.new()
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player.bus = Settings.MUSIC_BUS
	_player.volume_db = -60.0
	add_child(_player)
	set_process(false)


func play(track: String) -> void:
	if track == _current:
		return
	_current = track
	if _cache.has(track):
		_switch_to(_cache[track])
	elif not _tasks.has(track):
		_tasks[track] = WorkerThreadPool.add_task(_render.bind(track))
		set_process(true)


func _render(track: String) -> void:
	var stream := MusicSynth.render(track)
	_mutex.lock()
	_results[track] = stream
	_mutex.unlock()


## Biten üretim görevlerini ana iş parçacığında teslim alır.
func _process(_delta: float) -> void:
	for track in _tasks.keys():
		if not WorkerThreadPool.is_task_completed(_tasks[track]):
			continue
		WorkerThreadPool.wait_for_task_completion(_tasks[track])
		_tasks.erase(track)
		_mutex.lock()
		_cache[track] = _results[track]
		_results.erase(track)
		_mutex.unlock()
		if track == _current:
			_switch_to(_cache[track])
	set_process(not _tasks.is_empty())


func _switch_to(stream: AudioStream) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if _player.playing:
		_tween.tween_property(_player, "volume_db", -60.0, FADE_SEC)
	_tween.tween_callback(func() -> void:
		_player.stream = stream
		_player.play())
	_tween.tween_property(_player, "volume_db", VOLUME_DB, FADE_SEC)


func _exit_tree() -> void:
	# Kapanışta tween (akışa referans tutar) ve çalan akış bırakılmazsa sızıntı uyarısı oluşur.
	if _tween:
		_tween.kill()
		_tween = null
	_player.stop()
	_player.stream = null
	for id in _tasks.values():
		WorkerThreadPool.wait_for_task_completion(id)
	_tasks.clear()
	_results.clear()
