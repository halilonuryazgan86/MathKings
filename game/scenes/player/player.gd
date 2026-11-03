class_name Player
extends CharacterBody2D
## Platform hareketi: ivmelenme, coyote time, zıplama tamponu, değişken zıplama yüksekliği.

const SPEED := 330.0
const GROUND_ACCEL := 2600.0
const GROUND_FRICTION := 3200.0
const AIR_ACCEL := 1800.0
const GRAVITY := 1700.0
const MAX_FALL_SPEED := 1100.0
const JUMP_VELOCITY := -760.0
const JUMP_CUT_FACTOR := 0.45
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.12

var controls_enabled := true
var _coyote := 0.0
var _jump_buffer := 0.0

@onready var visual: CharacterVisual = $Visual
@onready var camera: Camera2D = $Camera2D


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right") if controls_enabled else 0.0

	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME
	else:
		_jump_buffer -= delta

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
	elif velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y = maxf(velocity.y, JUMP_VELOCITY * JUMP_CUT_FACTOR)

	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	if dir == 0.0 and is_on_floor():
		accel = GROUND_FRICTION
	velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)

	move_and_slide()
	_update_visual(dir)


func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	camera.reset_smoothing()
	var tw := create_tween()
	tw.tween_property(visual, "modulate:a", 0.3, 0.1)
	tw.tween_property(visual, "modulate:a", 1.0, 0.1)
	tw.set_loops(3)


func _update_visual(dir: float) -> void:
	if dir != 0.0:
		visual.facing = signf(dir)
	if not is_on_floor():
		visual.play("jump" if velocity.y < 0.0 else "fall")
	elif absf(velocity.x) > 20.0:
		visual.play("walk")
	else:
		visual.play("idle")
