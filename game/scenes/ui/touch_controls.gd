extends Control
## Çoklu dokunmatik kontroller: sol/sağ ok ve zıplama. Parmak butonlar arasında
## kaydırılabilir. Yalnızca dokunmatik ekranlı cihazlarda görünür.

const RADIUS := 80.0
const HIT_SCALE := 1.25
const MARGIN := 40.0

var _centers := {}   # action -> Vector2
var _touches := {}   # touch index -> action
var _pressed := {}   # action -> true


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = GameState.is_touch_ui()
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var y := size.y - MARGIN - RADIUS
	var x0 := MARGIN + RADIUS
	_centers = {
		"move_left": Vector2(x0, y),
		"move_right": Vector2(x0 + RADIUS * 2.0 + 36.0, y),
		"jump": Vector2(size.x - x0, y),
	}
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_set_touch(event.index, _action_at(event.position) if event.pressed else "")
	elif event is InputEventScreenDrag:
		_set_touch(event.index, _action_at(event.position))


func _notification(what: int) -> void:
	# Oyun duraklarken veya sahne kapanırken basılı kalan tuş bırakılmasın.
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		release_all()


func release_all() -> void:
	_touches.clear()
	for action in _pressed.keys():
		Input.action_release(action)
	_pressed.clear()
	queue_redraw()


func _action_at(pos: Vector2) -> String:
	for action in _centers:
		if pos.distance_to(_centers[action]) <= RADIUS * HIT_SCALE:
			return action
	return ""


func _set_touch(index: int, action: String) -> void:
	var old: String = _touches.get(index, "")
	if old == action:
		return
	if action.is_empty():
		_touches.erase(index)
	else:
		_touches[index] = action
	_sync(old)
	_sync(action)
	queue_redraw()


func _sync(action: String) -> void:
	if action.is_empty():
		return
	var want := action in _touches.values()
	if want and not _pressed.has(action):
		_pressed[action] = true
		Input.action_press(action)
	elif not want and _pressed.has(action):
		_pressed.erase(action)
		Input.action_release(action)


func _draw() -> void:
	for action in _centers:
		var c: Vector2 = _centers[action]
		var down := _pressed.has(action)
		draw_circle(c, RADIUS, Color(1, 1, 1, 0.45 if down else 0.25))
		draw_circle(c, RADIUS, Color(1, 1, 1, 0.7), false, 4.0)
		var s := RADIUS * 0.4
		var tri: PackedVector2Array
		match action:
			"move_left":
				tri = [c + Vector2(-s, 0), c + Vector2(s * 0.6, -s), c + Vector2(s * 0.6, s)]
			"move_right":
				tri = [c + Vector2(s, 0), c + Vector2(-s * 0.6, -s), c + Vector2(-s * 0.6, s)]
			_:
				tri = [c + Vector2(0, -s), c + Vector2(s, s * 0.6), c + Vector2(-s, s * 0.6)]
		draw_colored_polygon(tri, Color(1, 1, 1, 0.85))
