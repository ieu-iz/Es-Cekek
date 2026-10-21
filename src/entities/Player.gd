## Player.gd
# CharacterBody3D player. Plan §Architecture (Player) + Task 3.
# State machine: ROAM (free walk) <-> AT_STAND (locked to the stand counter).
# Movement: WASD/arrows on desktop, virtual joystick on Android.
extends CharacterBody3D

enum State { ROAM, AT_STAND }

const WALK_SPEED: float = 4.0
const RUN_SPEED: float = 7.0
const ACCELERATION: float = 14.0
const FRICTION: float = 16.0
const GRAVITY: float = 9.8
const TURN_SPEED: float = 12.0

## Distance from the counter where the player is considered "at the stand".
@export var stand_snap_distance: float = 2.0

var state: State = State.ROAM
var _current_stand: Node3D = null
var _look_at_stand: bool = false

@onready var body: Node3D = $Body
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var interact_area: Area3D = $InteractArea


func _ready() -> void:
	add_to_group("player")
	interact_area.body_entered.connect(_on_interact_area_body_entered)
	interact_area.body_exited.connect(_on_interact_area_body_exited)


func _physics_process(delta: float) -> void:
	# Gravity (always on).
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5

	var input_dir := _read_move_input()
	if state == State.AT_STAND:
		input_dir = Vector2.ZERO

	var target_speed := WALK_SPEED
	if Input.is_action_pressed("run") if InputMap.has_action("run") else false:
		target_speed = RUN_SPEED

	var wish := Vector3(input_dir.x, 0.0, -input_dir.y) * target_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if wish.length() > 0.01:
		horizontal = horizontal.move_toward(wish, ACCELERATION * delta)
	elif state == State.ROAM:
		horizontal = horizontal.move_toward(Vector3.ZERO, FRICTION * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	_update_facing(wish, delta)


func _read_move_input() -> Vector2:
	var dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Virtual joystick (Android) is published by UILayer.
	var joy := UILayer.move_vector
	if joy.length() > 0.01:
		# Joystick y is UP = forward, but Input.get_vector expects forward = -Y.
		dir += Vector2(joy.x, -joy.y)
	return dir.limit_length(1.0)


func _update_facing(wish: Vector3, delta: float) -> void:
	if _look_at_stand and _current_stand != null and is_instance_valid(_current_stand):
		var to_stand := _current_stand.global_position - global_position
		to_stand.y = 0.0
		if to_stand.length() > 0.01:
			_face(to_stand.normalized(), delta)
		return

	if wish.length() > 0.05:
		_face(wish.normalized(), delta)


func _face(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	body.rotation.y = lerp_angle(body.rotation.y, target_yaw, TURN_SPEED * delta)


# --- Interaction -------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()
		get_viewport().set_input_as_handled()


func _interact() -> void:
	if state == State.AT_STAND:
		_set_state(State.ROAM)
		UILayer.show_order("Tejus")
		return

	if _current_stand != null and is_instance_valid(_current_stand):
		_set_state(State.AT_STAND)
		# Snap next to the counter so the player is not stuck inside it.
		var target := _current_stand.global_position
		var offset := global_position - target
		offset.y = 0.0
		if offset.length() > 0.01:
			global_position = target + offset.normalized() * stand_snap_distance
		UILayer.show_order("Tejus")


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_look_at_stand = state == State.AT_STAND


func _on_interact_area_body_entered(body_node: Node3D) -> void:
	if body_node.is_in_group("stand"):
		_current_stand = body_node


func _on_interact_area_body_exited(body_node: Node3D) -> void:
	if body_node == _current_stand:
		_current_stand = null
		if state == State.AT_STAND:
			_set_state(State.ROAM)
