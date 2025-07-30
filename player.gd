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

func _ready() -> void:
	health = max_health
	$Sprite2D.texture = idle_texture

func _physics_process(delta: float) -> void:
	handle_movement(delta)
	handle_delayed_actions()

func handle_movement(delta: float) -> void:
	var input_vector = Vector2.ZERO
	var is_moving = false

	if Input.is_action_pressed("move_left_p%d" % player_id):
		input_vector.x -= 1
		is_moving = true
	elif Input.is_action_pressed("move_right_p%d" % player_id):
		input_vector.x += 1
		is_moving = true

	# Horizontal movement
	velocity.x = input_vector.x * speed

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# Jumping
	if Input.is_action_just_pressed("jump_p%d" % player_id) and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()

	# Animation swap logic for running
	if not _force_anim_override and is_on_floor():
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

func _unhandled_input(event: InputEvent) -> void:
	var now := Time.get_ticks_msec()

	if Input.is_action_pressed("punch_p%d" % player_id):
		if now - last_punch_time >= PUNCH_COOLDOWN_MS:
			input_queue.append({ "action": "punch", "time": now })
			last_punch_time = now
	elif Input.is_action_pressed("kick_p%d" % player_id):
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

	if is_inside_tree() and is_instance_valid($Sprite2D) and idle_texture:
		$Sprite2D.texture = idle_texture
	_force_anim_override = false

func check_hit(range: float, damage: int) -> void:
	if opponent and abs(position.x - opponent.position.x) < range:
		opponent.take_damage(damage)

func take_damage(amount: int) -> void:
	health -= amount
	print("Player %d got hit! HP: %d" % [player_id, health])
	if health_ui:
		health_ui.set_health(health)

	if health <= 0:
		if player_id == 1 and p2_win_scene:
			print("💥 Player 2 wins!")
			get_tree().change_scene_to_file(p2_win_scene)
		elif player_id == 2 and p1_win_scene:
			print("💥 Player 1 wins!")
			get_tree().change_scene_to_file(p1_win_scene)

func set_health_ui(ui: Node) -> void:
	health_ui = ui
	health_ui.set_health(health)
