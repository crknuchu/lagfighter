class_name Fighter
extends CharacterBody2D

const PUNCH_COOLDOWN_MS = 1000
const KICK_COOLDOWN_MS = 2000

const PUNCH_DAMAGE = 1
const KICK_DAMAGE = 2

@export var speed: float = 200.0
@export var jump_velocity: float = -350.0 # Negative because y+ is down in Godot
@export var gravity: float = 900.0
@export var attack_delay: float = 1.0
@export var player_id: int = 1  # 1 or 2
@export var max_health: int = 3

@export_file("*.tscn") var p1_win_scene: String
@export_file("*.tscn") var p2_win_scene: String

@export var idle_texture: Texture2D
@export var punch_texture: Texture2D
@export var kick_texture: Texture2D
@export var run_texture: Texture2D # For running

# Knockback parameters
@export var knockback_force: float = 300.0
@export var knockback_upward_force: float = -200.0

var last_punch_time: int = -1000
var last_kick_time: int = -2000

var input_queue: Array = []
var health: int = 3
var health_ui: Node = null

var opponent: Fighter

# Animation swap logic
var _run_anim_time := 0.0
var _run_anim_state := false # false=idle_texture, true=run_texture
var _force_anim_override := false

var _knockback_timer := 0.0
var _is_knockback := false

func _ready() -> void:
	health = max_health
	$Sprite2D.texture = idle_texture

func _physics_process(delta: float) -> void:
	handle_knockback(delta)
	handle_input()
	apply_gravity(delta)
	handle_animations(delta)
	move_and_slide()
	handle_attack_input()
	handle_delayed_actions()

func handle_knockback(delta: float) -> void:
	if _is_knockback:
		_knockback_timer -= delta
		if _knockback_timer <= 0:
			_is_knockback = false

func handle_input() -> void:
	if _is_knockback:
		return

	var input_vector = Vector2.ZERO
	if Input.is_action_pressed("move_left_p%d" % player_id):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right_p%d" % player_id):
		input_vector.x += 1
	velocity.x = input_vector.x * speed

	if Input.is_action_just_pressed("jump_p%d" % player_id) and is_on_floor():
		velocity.y = jump_velocity

func apply_gravity(delta: float) -> void:
	# Only apply gravity if not on floor or if moving up (for jump/knockback)
	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0:
		velocity.y = 0

func handle_animations(delta: float) -> void:
	if not _force_anim_override and not _is_knockback and is_on_floor():
		var is_moving = abs(velocity.x) > 0.1
		if is_moving and run_texture and idle_texture:
			_run_anim_time += delta
			if _run_anim_time >= 0.2:
				_run_anim_time = 0.0
				_run_anim_state = !_run_anim_state
			$Sprite2D.texture = run_texture if _run_anim_state else idle_texture
		elif idle_texture:
			_run_anim_time = 0.0
			_run_anim_state = false
			$Sprite2D.texture = idle_texture

func handle_attack_input() -> void:
	var now := Time.get_ticks_msec()
	if Input.is_action_just_pressed("punch_p%d" % player_id):
		if now - last_punch_time >= PUNCH_COOLDOWN_MS:
			input_queue.append({ "action": "punch", "time": now })
			last_punch_time = now
	elif Input.is_action_just_pressed("kick_p%d" % player_id):
		if now - last_kick_time >= KICK_COOLDOWN_MS:
			input_queue.append({ "action": "kick", "time": now })
			last_kick_time = now

func handle_delayed_actions() -> void:
	var now = Time.get_ticks_msec()
	var to_remove: Array = []

	for item in input_queue:
		if now - item["time"] >= int(attack_delay * 1000):
			perform_action(item["action"])
			to_remove.append(item)

	for item in to_remove:
		input_queue.erase(item)

func perform_action(action: String) -> void:
	_force_anim_override = true
	match action:
		"punch":
			if punch_texture:
				$Sprite2D.texture = punch_texture
			check_hit(40, PUNCH_DAMAGE)
			print("Player %d punches!" % player_id)
		"kick":
			if kick_texture:
				$Sprite2D.texture = kick_texture
			check_hit(60, KICK_DAMAGE)
			print("Player %d kicks!" % player_id)

	if !is_inside_tree():
		_force_anim_override = false
		return

	var delay = 0.2
	var timer := get_tree().create_timer(delay)
	if timer:
		await timer.timeout

	if !is_inside_tree():
		_force_anim_override = false
		return

	if is_instance_valid($Sprite2D) and idle_texture:
		$Sprite2D.texture = idle_texture
	_force_anim_override = false

func check_hit(range: float, damage: int) -> void:
	if opponent and abs(position.x - opponent.position.x) < range:
		var dir = sign(opponent.position.x - position.x)
		opponent.take_damage(damage, dir)

func take_damage(amount: int, knockback_dir := 0) -> void:
	health -= amount
	print("Player %d got hit! HP: %d" % [player_id, health])
	if health_ui:
		health_ui.set_health(health)

	# Apply knockback if direction is provided
	if knockback_dir != 0:
		velocity.x = knockback_dir * knockback_force
		velocity.y = knockback_upward_force
		_is_knockback = true
		_knockback_timer = 0.18 # seconds of knockback, tweak for feel

	if health <= 0:
		if player_id == 1 and p2_win_scene:
			await get_tree().create_timer(0.7).timeout
			get_tree().change_scene_to_file(p2_win_scene)
		elif player_id == 2 and p1_win_scene:
			await get_tree().create_timer(0.7).timeout
			get_tree().change_scene_to_file(p1_win_scene)

func set_health_ui(ui: Node) -> void:
	health_ui = ui
	health_ui.set_health(health)
