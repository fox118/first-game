extends Node2D

const MAX_HEALTH := 2
const CONTACT_DAMAGE := 1
const CONTACT_COOLDOWN := 0.8
const BOB_AMPLITUDE := 4.0
const BOB_SPEED := 2.5

@onready var hit_area: Area2D = $HitArea
@onready var sprite: Sprite2D = $Sprite

var health := MAX_HEALTH
var base_y := 0.0
var time := 0.0
var contact_cooldown_timer := 0.0
var dead := false

func _ready() -> void:
	base_y = position.y
	hit_area.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	time += delta
	position.y = base_y + sin(time * BOB_SPEED) * BOB_AMPLITUDE
	contact_cooldown_timer = max(contact_cooldown_timer - delta, 0.0)

func _on_body_entered(body: Node2D) -> void:
	if dead or contact_cooldown_timer > 0.0:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		contact_cooldown_timer = CONTACT_COOLDOWN
		body.take_damage(CONTACT_DAMAGE, global_position)

func take_hit() -> void:
	if dead:
		return
	health -= 1
	_flash()
	if health <= 0:
		_die()

func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(2.5, 2.5, 2.5), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)

func _die() -> void:
	dead = true
	hit_area.monitoring = false
	hit_area.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(queue_free)
