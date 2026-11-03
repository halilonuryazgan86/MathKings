extends Node2D
## Metin haritadan (LevelLayout) bölüm kurar; toplama, kontrol noktası, mini oyunlar ve bitişi yönetir.

const TILE := 64
const SOURCE_ID := 0
const COL_TOP := 0
const COL_FILL := 1
const COL_PLATFORM := 2
const THEME_ROWS := {"forest": 0, "cave": 1, "island": 2}
const FALL_MARGIN := 240.0

var level_id := ""
var _world := {}
var _theme_row := 0
var _bridge_cells: Array[Vector2i] = []
var _bridge_sign: BridgeSign
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
@onready var _treasure: TreasureHunt = $TreasureHunt
@onready var _bridge: FractionBridge = $FractionBridge


func _ready() -> void:
	level_id = GameState.current_level_id
	_world = GameState.world_for_level(level_id)
	_theme_row = THEME_ROWS.get(_world.get("theme", "forest"), 0)
	%Forest.backdrop_theme = _world.get("theme", "forest")
	_rows = LevelLayout.load_file(GameState.level_layout_path(level_id))
	if _rows.is_empty():
		GameState.go_to.call_deferred(GameState.SCENE_WORLD_MAP)
		return
	_build()
	_player.visual.character_id = GameState.save.character()
	_player.global_position = _checkpoint_pos
	_setup_bounds()
	_hud.set_stars(GameState.save.star_count(level_id), _stars_total)
	_hud.show_banner("%s · %s" % [tr(_world.get("nameKey", "")), GameState.level_name(level_id)])

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
			var top := cell.y == 0 or _char_at(cell + Vector2i.UP) != "#"
			_tiles.set_cell(cell, SOURCE_ID, _atlas(COL_TOP if top else COL_FILL))
		"=":
			_tiles.set_cell(cell, SOURCE_ID, _atlas(COL_PLATFORM))
		"c", "s":
			_add_pickup(ch, cell, center)
		"^", "~":
			var hazard := Hazard.new()
			hazard.style = "water" if ch == "~" else "thorns"
			hazard.position = bottom
			hazard.touched.connect(func() -> void: _player.respawn.call_deferred(_checkpoint_pos))
			_objects.add_child(hazard)
		"T":
			var chest := TreasureChest.new()
			chest.item_id = "%s%d_%d" % [SaveData.TREASURE_PREFIX, cell.x, cell.y]
			chest.opened = GameState.save.is_collected(level_id, chest.item_id)
			chest.position = bottom
			chest.reached.connect(_on_treasure_reached)
			_objects.add_child(chest)
		"B":
			_bridge_sign = BridgeSign.new()
			_bridge_sign.position = bottom
			_bridge_sign.reached.connect(_on_bridge_sign_reached)
			_objects.add_child(_bridge_sign)
		"_":
			_bridge_cells.append(cell)
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


func _atlas(column: int) -> Vector2i:
	return Vector2i(column, _theme_row)


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
	var monster := tr(_world.get("monster", {}).get("nameKey", "MONSTER_NUMBERS"))
	_owl.show_lines(PackedStringArray([tr("OWL_GATE_1"), tr("OWL_GATE_2").format({"monster": monster})]))
	await _owl.finished
	_battle.start(GameState.save.grade(), GameState.save.character(), _world)
	var battle_stars: int = await _battle.finished
	var reward := GameState.finish_battle(level_id, battle_stars)
	get_tree().paused = true
	_hud.show_result(_gold_this_run + reward, GameState.save.star_count(level_id), _stars_total, battle_stars,
		GameState.next_unlocked_level(level_id))


## İsteğe bağlı Hazine Avı. Vazgeçilirse sandık kapalı kalır; tekrar dokununca açılır.
func _on_treasure_reached(chest: TreasureChest) -> void:
	if _finished or _treasure.is_open():
		return
	_treasure.start(GameState.save.grade())
	var found: bool = await _treasure.finished
	if found and GameState.collect(level_id, chest.item_id):
		_gold_this_run += SaveData.TREASURE_GOLD
	chest.opened = GameState.save.is_collected(level_id, chest.item_id)


## Kesir Köprüsü: bulmaca çözülünce boşluğa tahtalar yerleşir.
func _on_bridge_sign_reached() -> void:
	if _bridge.is_open() or _bridge_sign.built:
		return
	_bridge.start(GameState.save.grade(), _world.get("questions", ""))
	await _bridge.finished
	_bridge_sign.built = true
	for cell in _bridge_cells:
		_tiles.set_cell(cell, SOURCE_ID, _atlas(COL_PLATFORM))
