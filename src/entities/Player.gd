## Player.gd
# CharacterBody3D player. Plan §Architecture (Player) + Task 3.
# State machine: ROAM (free walk) <-> AT_STAND (locked to the stand counter).
# Movement: WASD/arrows on desktop, virtual joystick on Android.
class_name Player
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
	if InputMap.has_action("run") and Input.is_action_pressed("run"):
		target_speed = RUN_SPEED

	var wish := input_to_world(input_dir) * target_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if wish.length() > 0.01:
		horizontal = horizontal.move_toward(wish, ACCELERATION * delta)
	elif state == State.ROAM:
		horizontal = horizontal.move_toward(Vector3.ZERO, FRICTION * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	_update_facing(wish, delta)


## Mapping arah input (datar) -> arah gerak di dunia.
##
## PENTING: `Input.get_vector(neg_x, pos_x, neg_y, pos_y)` mengembalikan
## y = -1 saat "move_forward" (W) ditekan dan y = +1 saat "move_back" (S).
## Kamera pemain menghadap ke -Z (depan = -Z), jadi:
##   W (y = -1) -> z = -1 (maju, menjauhi kamera)
##   S (y = +1) -> z = +1 (mundur, mendekati kamera)
## Tanda negate pernah terbalik di sini sehingga W berjalan mundur.
static func input_to_world(dir: Vector2) -> Vector3:
	return Vector3(dir.x, 0.0, dir.y)


func _read_move_input() -> Vector2:
	var dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Virtual joystick (Android) is published by UILayer.
	var joy := UILayer.move_vector
	if joy.length() > 0.01:
		# KONVENSI SAMA dengan Input.get_vector:
		#   x = +1 kanan, y = -1 maju/atas.
		# Joystick memakai koordinat layar (y ke bawah), jadi digeser ke atas
		# menghasilkan y negatif — persis seperti "move_forward" di keyboard.
		# Karena itu vektor joystick TIDAK boleh dinegasi lagi di sini.
		dir += joy
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
	# The prep panel swallows INTERACT while it is open (Batal closes it).
	if UILayer.is_prep_panel_open():
		_release_stand()
		return

	if state == State.AT_STAND:
		_set_state(State.ROAM)
		return

	if _current_stand != null and is_instance_valid(_current_stand):
		_set_state(State.AT_STAND)
		# Snap next to the counter so the player is not stuck inside it.
		var target := _current_stand.global_position
		var offset := global_position - target
		offset.y = 0.0
		if offset.length() > 0.01:
			global_position = target + offset.normalized() * stand_snap_distance
		# Opening the prep panel / serving happens on the stand itself.
		if _current_stand.has_method("interact_at_stand"):
			_current_stand.interact_at_stand()


## Step away from the counter (used when the prep panel closes).
## Only changes the state — it must never call back into close_prep(),
## otherwise the two would recurse.
func release_stand() -> void:
	_set_state(State.ROAM)


func _release_stand() -> void:
	_set_state(State.ROAM)
	var stand := _current_stand
	if stand != null and is_instance_valid(stand) and stand.has_method("close_prep"):
		stand.close_prep()


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_look_at_stand = state == State.AT_STAND


func _on_interact_area_body_entered(body_node: Node3D) -> void:
	var stand := _resolve_stand(body_node)
	if stand != null:
		_current_stand = stand


func _on_interact_area_body_exited(body_node: Node3D) -> void:
	var stand := _resolve_stand(body_node)
	if stand != null and stand == _current_stand:
		_current_stand = null
		if state == State.AT_STAND:
			_set_state(State.ROAM)


## The counter body sits inside the Stand node, so walk up to the node that
## actually knows how to open the prep panel.
func _resolve_stand(body_node: Node3D) -> Node3D:
	if body_node == null:
		return null
	if body_node.has_method("interact_at_stand"):
		return body_node
	var parent := body_node.get_parent()
	if parent != null and parent.has_method("interact_at_stand"):
		return parent as Node3D
	return null
