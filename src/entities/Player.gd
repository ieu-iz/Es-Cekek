## Player.gd
# Task 15 — first-person hands. Task 16 — kontrol layar sentuh.
#
# State machine: ROAM <-> AT_STAND <-> PREP.
#   ROAM: free walk (WASD / joystick).
#   AT_STAND: locked to the stand counter, INTERACT opens prep.
#   PREP: first-person hands — kamera di dalam rig, mouse untuk melihat,
#         klik-drag untuk mengambil & menggeser objek, Q menukar tangan,
#         R memutar badan, badan disembunyikan.
#
# Task 16 — satu mesin state pointer untuk mouse DAN multi-jari:
#   - 1 jari di objek       -> objek diambil tangan terdekat (mode "drag")
#   - 1 jari di area kosong -> melihat (mode "look")
#   - 2 jari               -> melihat (semua jari mode "look")
#   - mouse kiri tekan    -> ambil objek; mouse gerak -> melihat
#   - tombol layar "TUKAR TANGAN" / "PUTAR BADAN" menggantikan Q dan R.
#
# Catatan emulate mouse<->touch (lihat project.godot):
#   Android mengirim event sentuh ASLI *dan* mouse tiruan. Mouse tiruan
#   selalu datang lebih dulu untuk event "press", jadi kedua jalur harus
#   saling bantu: kalau ada jari aktif, semua event mouse diabaikan.
class_name Player
extends CharacterBody3D

enum State { ROAM, AT_STAND, PREP }

const WALK_SPEED: float = 4.0
const RUN_SPEED: float = 7.0
const ACCELERATION: float = 14.0
const FRICTION: float = 16.0
const GRAVITY: float = 9.8
const TURN_SPEED: float = 12.0

## Batas|first-person look (radian).
const LOOK_PITCH_LIMIT: float = deg_to_rad(35.0)
const LOOK_YAW_LIMIT: float = deg_to_rad(60.0)
## Sensibilitas mouse (derajat per piksel).
const LOOK_SENS: float = 0.22
## Kecepatan putar badan (derajat per detik).
const TURN_BODY_SPEED: float = 90.0
## Tinggi mata pemain saat di mode prep.
const EYE_HEIGHT: float = 1.6
## Pengali sensitivitas look untuk layar sentuh (1.0 = sama dengan mouse).
## Tempat pertama untuk tuning "feel" begitu ada feedback dari perangkat.
const TOUCH_LOOK_SENS_SCALE: float = 1.0
## Jarak maksimal (piksel) antara jari dan klik mouse tiruan untuk dianggap
## satu gestur yang sama (takeover drag).
const TOUCH_MOUSE_SLOP: float = 48.0
## Jarak rig first-person dari pusat konter (sisi vendor).
## Harus cukup jauh supaya seluruh lebar meja (2.36m) masuk pandangan
## horizontal kamera — kalau terlalu dekat, Sachet_1 & IceCooler jatuh di
## luar layar dan tidak bisa di-drag.
const PREP_STAND_OFFSET: float = 1.5
## Kemiringan pandang awal saat masuk mode prep (negatif = melihat ke bawah).
## supaya meja kerja langsung terlihat tanpa harus menggerakkan mouse dulu.
const PREP_START_PITCH: float = deg_to_rad(-25.0)

## Distance from the counter where the player snaps into PREP.
@export var stand_snap_distance: float = 1.8

var state: State = State.ROAM
var _current_stand: Node3D = null
var _look_at_stand: bool = false

## First-person rig + camera.
@onready var prep_rig: Node3D = $PrepRig
@onready var prep_camera: Camera3D = $PrepRig/Camera3D
@onready var left_hand: Hand = $PrepRig/LeftHand
@onready var right_hand: Hand = $PrepRig/RightHand
@onready var prep_controller: PrepController = $PrepController

@onready var body: Node3D = $Body
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var interact_area: Area3D = $InteractArea

var _yaw: float = 0.0
var _pitch: float = 0.0
var _body_yaw: float = 0.0
## Yaw dasar (arah menghadap meja) — pandangan hanya boleh +/- LOOK_YAW_LIMIT.
var _yaw_base: float = 0.0

# --- Task 16 — state pointer (mouse + multi-jari) ---
## Jari yang sedang aktif: index -> {mode: "look"/"drag", pos: Vector2}.
var _touch_points: Dictionary = {}
## Index jari yang sedang dragging objek (-1 = tidak ada / drag oleh mouse).
var _drag_touch_index: int = -1
## Mouse sedang dragging objek?
var _mouse_dragging: bool = false
## Posisi klik mouse terakhir (dipakai untuk mencocokkan mouse tiruan dengan jari).
var _last_mouse_press_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	interact_area.body_entered.connect(_on_interact_area_body_entered)
	interact_area.body_exited.connect(_on_interact_area_body_exited)
	# Tombol layar untuk aksi first-person (TUKAR TANGAN / PUTAR BADAN).
	var on_prep_action := _on_prep_action
	if not UILayer.prep_action.is_connected(on_prep_action):
		UILayer.prep_action.connect(on_prep_action)


func _physics_process(delta: float) -> void:
	if state == State.PREP:
		_update_prep(delta)
	else:
		_update_movement(delta)


func _update_movement(delta: float) -> void:
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


# --- First-person prep --------------------------------------------------

func _update_prep(delta: float) -> void:
	# Badan disembunyikan selama di mode prep.
	if body != null:
		body.visible = false

	# R memutar badan (bukan pandangan) — vendor bisa berbalik.
	if InputMap.has_action("turn_body") and Input.is_action_pressed("turn_body"):
		_body_yaw = fmod(_body_yaw + TURN_BODY_SPEED * delta, 360.0)
	if body != null:
		body.rotation.y = deg_to_rad(_body_yaw)

	# Rig + kamera mengikuti sudut pandang.
	prep_rig.rotation.y = _yaw
	prep_camera.rotation.x = _pitch


# --- Interaction --------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Di mode prep, SEMUA event pointer (mouse + jari) dipakai oleh mesin
	# state di bawah supaya tidak ada double handling antara mouse & touch.
	if state == State.PREP and handle_prep_pointer(event):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact"):
		_interact()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("swap_hand"):
		if state == State.PREP and prep_controller != null:
			prep_controller.swap_hands()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("prep_exit"):
		if state == State.PREP:
			_exit_prep()
		get_viewport().set_input_as_handled()
		return


# --- Task 16 — mesin state pointer (mouse + multi-jari) -------------------

## Tangani satu event pointer di mode prep.
## Mengembalikan true kalau event itu sudah dipakai (jadi tidak diteruskan).
## Publik (bukan underscore) supaya bisa diuji di `tests/runtime_test.gd`.
func handle_prep_pointer(event: InputEvent) -> bool:
	# Urutan penting: ScreenDrag diperiksa lebih dulu karena di beberapa
	# versi Godot ia mewarisi ScreenTouch.
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touch_drag(sd.index, sd.position, sd.relative)
		return true

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touch_press(st.index, st.position)
		else:
			_touch_release(st.index, st.position)
		return true

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		if mb.pressed:
			_mouse_press(mb.position)
		else:
			_mouse_release(mb.position)
		return true

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mouse_move(mm.position, mm.relative)
		return true

	return false


## Jari ditekan di layar.
func _touch_press(index: int, pos: Vector2) -> void:
	_touch_points[index] = {"mode": "look", "pos": pos}
	if prep_controller == null:
		return

	# Android mengirim event mouse TIRUAN sebelum event sentuh asli. Kalau
	# mouse tiruan itu sudah grabbing objek, jari ini yang sebenarnya
	# responsible -> takeover drag-nya (bukan untuk melihat).
	if _mouse_dragging and prep_controller.dragging:
		if pos.distance_to(_last_mouse_press_pos) <= TOUCH_MOUSE_SLOP:
			_mouse_dragging = false
			_drag_touch_index = index
			_touch_points[index]["mode"] = "drag"
			return

	# Sudah ada objek yang sedang di-drag -> jari ini untuk melihat.
	if prep_controller.dragging:
		return

	# Jari di objek -> ambil; di area kosong -> melihat.
	if prep_controller.begin_drag_at(pos):
		_drag_touch_index = index
		_touch_points[index]["mode"] = "drag"


## Jari digeser di layar.
func _touch_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if not _touch_points.has(index):
		return
	var mode := str(_touch_points[index].get("mode", "look"))
	_touch_points[index]["pos"] = pos
	if mode == "drag":
		if prep_controller != null:
			prep_controller.set_pointer(pos)
		return
	# Jari lain (mode look) tidak boleh memutar pandangan selama ada objek
	# yang sedang di-drag, kalau tidak objeknya ikut tereser.
	if prep_controller != null and prep_controller.dragging:
		return
	apply_look(relative, TOUCH_LOOK_SENS_SCALE)


## Jari dilepas dari layar.
func _touch_release(index: int, pos: Vector2) -> void:
	if not _touch_points.has(index):
		return
	var mode := str(_touch_points[index].get("mode", "look"))
	_touch_points.erase(index)
	if mode == "drag":
		_drag_touch_index = -1
		if prep_controller != null:
			prep_controller.end_drag_at(pos)


## Klik kiri mouse ditekan.
func _mouse_press(pos: Vector2) -> void:
	# Ada jari aktif -> event mouse ini hasil emulasi touch->mouse, abaikan.
	if _touch_points.size() > 0:
		return
	_last_mouse_press_pos = pos
	if prep_controller == null:
		return
	if prep_controller.begin_drag_at(pos):
		_mouse_dragging = true


## Klik kiri mouse dilepas.
func _mouse_release(pos: Vector2) -> void:
	if not _mouse_dragging:
		return
	_mouse_dragging = false
	if prep_controller != null:
		prep_controller.end_drag_at(pos)


## Mouse bergerak.
func _mouse_move(pos: Vector2, relative: Vector2) -> void:
	# Ada jari aktif -> mouse motion ini emulasi dari touch yang sama, jadi
	# diabaikan supaya pandangan tidak berputar dua kali.
	if _touch_points.size() > 0:
		return
	if prep_controller != null and prep_controller.dragging:
		prep_controller.set_pointer(pos)
		return
	apply_look(relative, 1.0)


## Geser pandangan (mouse atau jari). `relative` dalam piksel viewport.
func apply_look(relative: Vector2, sens_scale: float = 1.0) -> void:
	if state != State.PREP:
		return
	_yaw = clampf(
		_yaw - deg_to_rad(relative.x) * LOOK_SENS * sens_scale,
		_yaw_base - LOOK_YAW_LIMIT,
		_yaw_base + LOOK_YAW_LIMIT
	)
	_pitch = clampf(
		_pitch - deg_to_rad(relative.y) * LOOK_SENS * sens_scale,
		-LOOK_PITCH_LIMIT,
		LOOK_PITCH_LIMIT
	)


## Putar badan (bukan pandangan). Dipakai tombol R dan tombol layar.
func turn_body(amount_deg: float = 180.0) -> void:
	_body_yaw = fmod(_body_yaw + amount_deg, 360.0)


## Aksi HUD mode prep yang khusus untuk pemain (Task 16).
## Tombol "TUKAR TANGAN" menggantikan Q, "PUTAR BADAN" menggantikan R.
func _on_prep_action(action: StringName, _value: float) -> void:
	match action:
		UILayer.ACTION_SWAP_HAND:
			if state == State.PREP and prep_controller != null:
				prep_controller.swap_hands()
		UILayer.ACTION_TURN_BODY:
			if state == State.PREP:
				turn_body(180.0)


func _interact() -> void:
	if state == State.PREP:
		exit_prep_mode()
		return

	if state == State.AT_STAND:
		# Delegasi ke stand (stand yang mengaktifkan mode first-person).
		if _current_stand != null and is_instance_valid(_current_stand) and _current_stand.has_method("interact_at_stand"):
			_current_stand.interact_at_stand()
		return

	if _current_stand != null and is_instance_valid(_current_stand):
		_set_state(State.AT_STAND)
		# Snap next to the counter so the player is not stuck inside it.
		var target := _current_stand.global_position
		var offset := global_position - target
		offset.y = 0.0
		if offset.length() > 0.01:
			global_position = target + offset.normalized() * stand_snap_distance
		# Masuk mode prep / menyajikan terjadi di stand itu sendiri.
		if _current_stand.has_method("interact_at_stand"):
			_current_stand.interact_at_stand()


## Dipanggil Stand saat pemain menekan INTERACT di meja.
func enter_prep_mode(stand: Stand) -> void:
	if stand != null:
		_current_stand = stand
	_enter_prep()


## Dipanggil Stand / HUD saat pemain keluar dari mode prep.
func exit_prep_mode() -> void:
	_exit_prep()


## Masuk mode first-person di meja.
func _enter_prep() -> void:
	if _current_stand == null or not is_instance_valid(_current_stand):
		return
	_set_state(State.PREP)

	# Vendor berdiri di sisi meja yang berlawanan dengan pelanggan (sisi -Z
	# lokal stand), supaya meja & pelanggan ada di depan mata.
	var stand_xform := _current_stand.global_transform
	var rig_pos := stand_xform * Vector3(0.0, 0.0, -PREP_STAND_OFFSET)
	var fwd := (stand_xform.basis * Vector3(0.0, 0.0, 1.0)).normalized()
	var world_yaw := atan2(-fwd.x, -fwd.z)

	# Rig first-person: setinggi mata, menghadap meja.
	prep_rig.global_position = Vector3(rig_pos.x, rig_pos.y + EYE_HEIGHT, rig_pos.z)
	_yaw_base = world_yaw
	_yaw = world_yaw
	# Pandangan awal sedikit ke bawah supaya meja kerja langsung terlihat.
	_pitch = PREP_START_PITCH
	prep_rig.rotation.y = _yaw
	prep_camera.rotation.x = _pitch

	# Badan disembunyikan.
	if body != null:
		body.visible = false
	# `_body_yaw` disimpan dalam DERAJAT, `rotation.y` memakai RADIAN.
	_body_yaw = rad_to_deg(world_yaw)
	if body != null:
		body.rotation.y = deg_to_rad(_body_yaw)

	# Kamera pertama-person yang aktif.
	if camera != null:
		camera.current = false
	if prep_camera != null:
		prep_camera.current = true

	# Tangan mulai kosong & di posisi resting.
	left_hand.holds = null
	right_hand.holds = null
	left_hand.position = Vector3(-0.24, -0.28, -0.45)
	right_hand.position = Vector3(0.24, -0.28, -0.45)

	# Kabari stand & controller.
	if _current_stand.has_method("enter_prep"):
		_current_stand.enter_prep()
	if prep_controller != null:
		prep_controller.enter(_current_stand as Stand)


## Keluar dari mode first-person.
func _exit_prep() -> void:
	_set_state(State.AT_STAND)

	# Bersihkan state pointer supaya tidak ada jari/mouse nyangkut.
	_touch_points.clear()
	_drag_touch_index = -1
	_mouse_dragging = false

	if prep_controller != null:
		prep_controller.exit()

	# Kamera third-person aktif lagi.
	if prep_camera != null:
		prep_camera.current = false
	if camera != null:
		camera.current = true

	# Badan terlihat lagi.
	if body != null:
		body.visible = true

	# Kabari stand.
	if _current_stand != null and is_instance_valid(_current_stand) and _current_stand.has_method("exit_prep"):
		_current_stand.exit_prep()


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
