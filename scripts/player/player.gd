extends CharacterBody2D

const SPEED := 140.0
const ACCEL := 1200.0
const FRICTION := 1400.0
const AIR_ACCEL := 900.0

const GRAVITY := 900.0
const GLIDE_GRAVITY := 120.0
const MAX_FALL_SPEED := 420.0
const GLIDE_MAX_FALL_SPEED := 60.0

const JUMP_VELOCITY := -300.0
const JUMP_CUT_MULTIPLIER := 0.45
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.12

const ATTACK_DURATION := 0.22
const ATTACK_HITBOX_START := 0.05
const ATTACK_HITBOX_END := 0.15
const SWING_START_ANGLE := -1.1
const SWING_END_ANGLE := 1.3

const PARRY_WINDOW := 0.15

const MAX_HEALTH := 5
const INVULN_TIME := 0.6
const HIT_KNOCKBACK := Vector2(160.0, -140.0)
const BLINK_RATE := 20.0
const DEATH_FADE_TIME := 0.35

@onready var facing_pivot: Node2D = $FacingPivot
@onready var umbrella_pivot: Node2D = $FacingPivot/UmbrellaPivot
@onready var umbrella_sprite: Sprite2D = $FacingPivot/UmbrellaPivot/UmbrellaSprite
@onready var cat_sprite: Sprite2D = $FacingPivot/CatSprite
@onready var attack_hitbox: Area2D = $FacingPivot/AttackHitbox
@onready var death_fade: ColorRect = $DeathFade/Fade

var umbrella_closed_tex: Texture2D = preload("res://assets/sprites/player/umbrella_closed.png")
var umbrella_open_tex: Texture2D = preload("res://assets/sprites/player/umbrella_open.png")

var facing_dir := 1

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

var is_attacking := false
var attack_timer := 0.0

var is_guarding := false
var guard_hold_timer := 0.0
var can_parry := false

var health := MAX_HEALTH
var invuln_timer := 0.0
var respawn_position := Vector2.ZERO

func _ready() -> void:
	attack_hitbox.monitoring = false
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	respawn_position = global_position

func _physics_process(delta: float) -> void:
	_read_guard_input(delta)
	_read_jump_buffer(delta)
	_update_invulnerability(delta)

	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	_apply_gravity(delta)
	_handle_jump()
	_handle_attack(delta)
	_handle_horizontal_movement(delta)

	move_and_slide()

	_update_umbrella_visual()

func _read_guard_input(delta: float) -> void:
	if Input.is_action_just_pressed("guard"):
		is_guarding = true
		guard_hold_timer = 0.0
	elif Input.is_action_pressed("guard"):
		is_guarding = true
		guard_hold_timer += delta
	else:
		is_guarding = false
		guard_hold_timer = 0.0

	can_parry = is_guarding and guard_hold_timer <= PARRY_WINDOW

func _update_invulnerability(delta: float) -> void:
	invuln_timer = max(invuln_timer - delta, 0.0)
	cat_sprite.visible = invuln_timer <= 0.0 or int(invuln_timer * BLINK_RATE) % 2 == 0

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target and target.has_method("take_hit"):
		target.take_hit()

func take_damage(amount: int, source_position: Vector2) -> void:
	if invuln_timer > 0.0:
		return
	if is_guarding:
		# parry timing (can_parry) is tracked but not yet differentiated here;
		# reserved for a future stagger/reflect reaction once enemies support it
		return

	health -= amount
	invuln_timer = INVULN_TIME
	var dir := int(sign(global_position.x - source_position.x))
	if dir == 0:
		dir = -facing_dir
	velocity = Vector2(HIT_KNOCKBACK.x * dir, HIT_KNOCKBACK.y)

	if health <= 0:
		die()

func die() -> void:
	health = MAX_HEALTH
	velocity = Vector2.ZERO
	is_attacking = false
	is_guarding = false
	attack_hitbox.monitoring = false
	invuln_timer = INVULN_TIME
	global_position = respawn_position
	death_fade.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(death_fade, "modulate:a", 0.0, DEATH_FADE_TIME)

func _read_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	var gliding := is_guarding and velocity.y > 0.0
	var gravity := GLIDE_GRAVITY if gliding else GRAVITY
	var max_fall := GLIDE_MAX_FALL_SPEED if gliding else MAX_FALL_SPEED

	velocity.y = min(velocity.y + gravity * delta, max_fall)

func _handle_jump() -> void:
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULTIPLIER

func _handle_attack(delta: float) -> void:
	if not is_attacking and Input.is_action_just_pressed("attack") and not is_guarding:
		_start_attack()

	if not is_attacking:
		return

	attack_timer += delta
	attack_hitbox.monitoring = attack_timer >= ATTACK_HITBOX_START and attack_timer < ATTACK_HITBOX_END

	if attack_timer >= ATTACK_DURATION:
		is_attacking = false
		attack_hitbox.monitoring = false

func _start_attack() -> void:
	is_attacking = true
	attack_timer = 0.0
	umbrella_sprite.texture = umbrella_closed_tex
	umbrella_pivot.rotation = SWING_START_ANGLE
	var tween := create_tween()
	tween.tween_property(umbrella_pivot, "rotation", SWING_END_ANGLE, ATTACK_DURATION).set_ease(Tween.EASE_OUT)

func _handle_horizontal_movement(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")

	if input_dir != 0.0:
		facing_dir = int(sign(input_dir))
		facing_pivot.scale.x = facing_dir

	if is_guarding and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		return

	var target_speed := input_dir * SPEED
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	if input_dir == 0.0:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	else:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)

func _update_umbrella_visual() -> void:
	if is_attacking:
		return

	if is_guarding:
		umbrella_sprite.texture = umbrella_open_tex
		umbrella_pivot.rotation = lerp_angle(umbrella_pivot.rotation, 0.0, 0.3)
	else:
		umbrella_sprite.texture = umbrella_closed_tex
		umbrella_pivot.rotation = lerp_angle(umbrella_pivot.rotation, 0.0, 0.2)
