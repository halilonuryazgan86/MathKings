extends Node2D
## Metin haritadan (LevelLayout) bölüm kurar; toplama, kontrol noktası ve bitişi yönetir.

const TILE := 64
const SOURCE_ID := 0
const ATLAS_GRASS := Vector2i(0, 0)
const ATLAS_DIRT := Vector2i(1, 0)
const ATLAS_PLATFORM := Vector2i(2, 0)
const FALL_MARGIN := 240.0

var level_id := ""
var _rows := PackedStringArray()
var _map_px := Vector2.ZERO
var _checkpoint_pos := Vector2.ZERO
var _active_checkpoint: Checkpoint
var _stars_total := 0
var _gold_this_run := 0
var _finished := false

@onready var _tiles: TileMapLayer = $Tiles
@onready var _objects: Node2D = $Objects
@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud
@onready var _owl: OwlDialog = $OwlDialog
@onready var _battle: MathBattle = $MathBattle


func _ready() -> void:
	level_id = GameState.current_level_id
	_rows = LevelLayout.load_file(GameState.level_layout_path(level_id))
	if _rows.is_empty():
		GameState.go_to(GameState.SCENE_MAIN_MENU)
		return
	_build()
	_player.visual.character_id = GameState.save.character()
	_player.global_position = _checkpoint_pos
	_setup_bounds()
	_hud.set_stars(GameState.save.star_count(level_id), _stars_total)

	if not GameState.save.seen_intro():
		_show_intro.call_deferred()


func _physics_process(_delta: float) -> void:
	if not _finished and _player.global_position.y > _map_px.y + FALL_MARGIN:
		_player.respawn(_checkpoint_pos)


func _show_intro() -> void:
	var controls_key := "OWL_CONTROLS_TOUCH" if DisplayServer.is_touchscreen_available() else "OWL_CONTROLS_KEYS"
	_owl.show_lines(PackedStringArray([
		tr("OWL_INTRO_1").format({"name": GameState.save.nickname()}),
		tr("OWL_INTRO_2"),
		tr("OWL_INTRO_3"),
		tr(controls_key),
	]))
	await _owl.finished
	GameState.save.mark_intro_seen()
	GameState.persist()


# --- Kurulum -----------------------------------------------------------------

func _build() -> void:
	var height := _rows.size()
	var width := _rows[0].length()
	_map_px = Vector2(width * TILE, height * TILE)
	for y in height:
		for x in width:
			_build_cell(_rows[y][x], Vector2i(x, y))


func _build_cell(ch: String, cell: Vector2i) -> void:
	var bottom := Vector2(cell.x * TILE + TILE / 2.0, (cell.y + 1) * TILE)
	var center := bottom - Vector2(0, TILE / 2.0)
	match ch:
		"#":
			var grass := cell.y == 0 or _char_at(cell + Vector2i.UP) != "#"
			_tiles.set_cell(cell, SOURCE_ID, ATLAS_GRASS if grass else ATLAS_DIRT)
		"=":
			_tiles.set_cell(cell, SOURCE_ID, ATLAS_PLATFORM)
		"c", "s":
			_add_pickup(ch, cell, center)
		"^":
			var hazard := Hazard.new()
			hazard.position = bottom
			hazard.touched.connect(func() -> void: _player.respawn.call_deferred(_checkpoint_pos))
			_objects.add_child(hazard)
		"C":
			var cp := Checkpoint.new()
			cp.position = bottom
			cp.reached.connect(_on_checkpoint_reached)
			_objects.add_child(cp)
		"P":
			_checkpoint_pos = bottom
		"G":
			var gate := CrystalGate.new()
			gate.position = bottom
			gate.reached.connect(_on_gate_reached)
			_objects.add_child(gate)


func _add_pickup(ch: String, cell: Vector2i, pos: Vector2) -> void:
	var p := Pickup.new()
	p.kind = Pickup.Kind.STAR if ch == "s" else Pickup.Kind.COIN
	var prefix := SaveData.STAR_PREFIX if ch == "s" else SaveData.COIN_PREFIX
	p.item_id = "%s%d_%d" % [prefix, cell.x, cell.y]
	p.already_collected = GameState.save.is_collected(level_id, p.item_id)
	p.position = pos
	p.picked.connect(_on_picked)
	if ch == "s":
		_stars_total += 1
	_objects.add_child(p)


func _setup_bounds() -> void:
	var cam := _player.camera
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(_map_px.x)
	cam.limit_bottom = int(_map_px.y)
	cam.reset_smoothing()
	# Görünmez sol/sağ duvarlar
	for side in [[0.0, Vector2.RIGHT], [_map_px.x, Vector2.LEFT]]:
		var wall := StaticBody2D.new()
		var shape := WorldBoundaryShape2D.new()
		shape.normal = side[1]
		var cs := CollisionShape2D.new()
		cs.shape = shape
		wall.position = Vector2(side[0], 0)
		wall.add_child(cs)
		add_child(wall)


func _char_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= _rows.size() or cell.x < 0 or cell.x >= _rows[cell.y].length():
		return LevelLayout.EMPTY
	return _rows[cell.y][cell.x]


# --- Olaylar -----------------------------------------------------------------

func _on_picked(p: Pickup) -> void:
	if GameState.collect(level_id, p.item_id):
		_gold_this_run += p.gold_value()
		Sfx.play(self, "coin")
		if p.kind == Pickup.Kind.STAR:
			_hud.set_stars(GameState.save.star_count(level_id), _stars_total)


func _on_checkpoint_reached(cp: Checkpoint) -> void:
	if _active_checkpoint != null and _active_checkpoint.position.x > cp.position.x:
		return  # Geriye dönünce eski bayrak aktifleşmesin.
	_active_checkpoint = cp
	cp.activate()
	_checkpoint_pos = cp.global_position


func _on_gate_reached() -> void:
	if _finished:
		return
	_finished = true
	_player.controls_enabled = false
	_owl.show_lines(PackedStringArray([tr("OWL_GATE_1"), tr("OWL_GATE_2")]))
	await _owl.finished
	_battle.start(GameState.save.grade(), GameState.save.character())
	var battle_stars: int = await _battle.finished
	var reward := GameState.finish_battle(level_id, battle_stars)
	get_tree().paused = true
	_hud.show_result(_gold_this_run + reward, GameState.save.star_count(level_id), _stars_total, battle_stars)
