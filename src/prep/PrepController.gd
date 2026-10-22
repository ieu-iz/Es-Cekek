## PrepController.gd
# Task 15 — first-person hands. Task 16 — kontrol layar sentuh.
#
# Mengatur seluruh interaksi meja:
#   - klik/tap objek  -> tangan terdekat mengambilnya (tangan yang free kalau
#     tangan terdekat sudah memegang sesuatu),
#   - drag mouse      -> objek dipegang bergerak mengikuti kursor di meja,
#   - Q                -> menukar isi kedua tangan,
#   - dua objek brought dekat -> `RecipeRules` memicu langkah resep.
#
# Task 16: semua posisi pointer (mouse ATAU jari) masuk lewat fungsi
# `begin_drag_at()` / `end_drag_at()` / `set_pointer()` yang menerima
# koordinat layar eksplisit. `Player` yang memutuskan apakah sebuah pointer
# itu "ambil objek" atau "lihat", sehingga mouse dan multi-jari bisa berbagi
# satu mesin state tanpa saling menabrak.
#
# Controller ini adalah anak dari Player (bukan autoload) supaya bisa
# memakai kamera & tangan milik rig first-person.
class_name PrepController
extends Node3D

## Jangkauan maksimum tangan dari kamera (meter).
## Harus cukup besar untuk mencapai seluruh meja (lebar 2.36m) dari posisi
## kamera first-person (jarak datar ~1.7m ke sudut terjauh).
const REACH: float = 2.2
## Jarak es -> pelanggan untuk dianggap "diserahkan".
const CUSTOMER_TAKE_DIST: float = 1.60
## Jeda antar komplain (detik) supaya pelanggan tidak spam.
const COMPLAIN_COOLDOWN: float = 4.0

## Controller aktif (pemain sedang di mode prep)?
var active: bool = false
## Stand yang sedang dikerjakan.
var stand: Stand = null
## Sesi resep (mesin state).
var session: PrepStation = null

## Sedang dragging objek?
var dragging: bool = false
## Objek yang sedang didrag.
var dragged: PrepObject = null
## Tangan pilihan (0 = kiri, 1 = kanan) — dipakai saat jarak keduanya sama.
var preferred: int = 1
## Posisi pointer (mouse atau jari) terakhir, koordinat viewport.
## Dipakai untuk memproyeksikan titik ke meja kerja.
var pointer_screen: Vector2 = Vector2.ZERO

var _last_complain: float = -999.0
var _customer_called: bool = false

@onready var camera: Camera3D = get_node_or_null("../PrepRig/Camera3D") as Camera3D
@onready var left_hand: Hand = get_node_or_null("../PrepRig/LeftHand") as Hand
@onready var right_hand: Hand = get_node_or_null("../PrepRig/RightHand") as Hand


func _ready() -> void:
	# Autoload PrepController (jika ada) tidak boleh ikut memproses.
	set_process(false)


func _process(delta: float) -> void:
	if not active or session == null:
		return
	_update_drag()
	_evaluate_rules()
	_check_customer(delta)


# --- Masuk / keluar mode prep -------------------------------------------

## Mulai bekerja di stand.
func enter(stand_node: Stand) -> void:
	stand = stand_node
	if stand != null:
		session = stand.prep_station
	active = true
	dragging = false
	dragged = null
	_customer_called = false
	if session != null:
		session.open_build()
	set_process(true)
	UILayer.show_prep_panel(true)


## Selesai bekerja — semua objek dikembalikan ke meja.
func exit() -> void:
	active = false
	set_process(false)
	_drop_held(left_hand)
	_drop_held(right_hand)
	dragging = false
	dragged = null
	UILayer.show_prep_panel(false)


## Letakkan objek yang dipegang kembali ke meja.
func _drop_held(hand: Hand) -> void:
	if hand == null or hand.holds == null:
		return
	var obj := hand.holds
	var home := obj.home_transform.origin
	var parent := obj.home_parent
	if parent != null and is_instance_valid(parent):
		var world_home := parent.to_global(home)
		hand.release_at(world_home, obj.home_transform.basis.get_euler().y)
	else:
		hand.release()


# --- Input (Task 16: mouse + layar sentuh) -------------------------------
#
# Controller TIDAK lagi membaca event input sendiri. `Player` yang memegang
# semua event pointer dan meneruskannya ke sini lewat fungsi di bawah, supaya
# mouse dan multi-jari cukup berbagi satu jalur.

## Ambil objek di bawah posisi layar tertentu (koordinat viewport).
## Mengembalikan true kalau objek benar-benar berhasil dipegang.
func begin_drag_at(screen_pos: Vector2) -> bool:
	pointer_screen = screen_pos
	var obj := pick_object_at(screen_pos)
	if obj == null:
		return false
	var hand := _choose_hand(obj)
	if hand == null:
		UILayer.show_error("Kedua tangan sedang memegang barang.")
		return false
	hand.grab(obj)
	if not hand.holds:
		return false
	dragging = true
	dragged = obj
	# Plastik adalah wadah pembuatan es.
	if obj.is_vessel() and session != null:
		session.set_vessel(obj)
	# Ambil sachet = brand yang sedang dibuat.
	if int(obj.kind) == PrepObject.Kind.SACHET and obj.brand != null and session != null:
		session.select_brand(obj.brand)
	return true


## Lepas objek yang dipegang pada posisi layar tertentu.
func end_drag_at(screen_pos: Vector2) -> void:
	pointer_screen = screen_pos
	if not dragging:
		return
	dragging = false
	var obj := dragged
	dragged = null
	if obj == null:
		return
	var hand := obj.held_by
	if hand == null:
		return
	var p := _cursor_on_work_plane_at(screen_pos)
	if p == Vector3.INF:
		_drop_held(hand)
		return
	hand.release_at(p, randf_range(-PI, PI))
	# Melepaskan wadah di dekat pelanggan = mencoba menyerahkan es.
	if session != null and obj == session.vessel:
		_try_handover(obj)


## Gerakkan pointer — objek yang sedang dipegang ikut bergerak mengikuti kursor.
func set_pointer(screen_pos: Vector2) -> void:
	pointer_screen = screen_pos
	_update_drag()


## Pilih tangan: yang paling dekat dengan objek. Kalau tangan itu penuh,
## tangan lain yang free yang mengambil.
func _choose_hand(obj: PrepObject) -> Hand:
	if left_hand == null or right_hand == null:
		return null
	var dl := left_hand.grip_position().distance_to(obj.global_position)
	var dr := right_hand.grip_position().distance_to(obj.global_position)
	var nearest := left_hand if dl <= dr else right_hand
	var other := right_hand if nearest == left_hand else left_hand
	# Kalau jarak nyaris sama, pakai tangan pilihan (tombol Q).
	if absf(dl - dr) < 0.05:
		nearest = left_hand if preferred == 0 else right_hand
		other = right_hand if nearest == left_hand else left_hand
	if nearest.is_free():
		return nearest
	if other.is_free():
		return other
	return null


## Tukar isi kedua tangan (tombol Q).
func swap_hands() -> void:
	if left_hand == null or right_hand == null:
		return
	var l := left_hand.holds
	var r := right_hand.holds
	left_hand.holds = null
	right_hand.holds = null
	if l != null:
		l.held_by = null
		right_hand.grab(l)
	if r != null:
		r.held_by = null
		left_hand.grab(r)
	preferred = 1 - preferred


# --- Picking -------------------------------------------------------------

## Gerakkan objek yang sedang didrag mengikuti kursor di meja kerja.
func _update_drag() -> void:
	if not dragging or dragged == null or camera == null:
		return
	var hand := dragged.held_by
	if hand == null:
		return
	var target := _cursor_on_work_plane_at(pointer_screen)
	if target == Vector3.INF:
		return
	# Tangan digeser supaya ujung jarinya ada di titik target.
	hand.global_position = target - (hand.global_basis * hand.grip_offset)


## Objek apa yang ada di bawah posisi layar tertentu?
func pick_object_at(screen_pos: Vector2) -> PrepObject:
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(origin, origin + dir * 6.0)
	params.collision_mask = PrepObject.PICK_LAYER
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return null
	var node := hit.get("collider") as Node
	while node != null and not (node is PrepObject):
		node = node.get_parent()
	return node as PrepObject


## Titik di meja kerja yang ditunjuk posisi layar tertentu
## (Vector3.INF kalau tidak kena).
func _cursor_on_work_plane_at(screen_pos: Vector2) -> Vector3:
	if camera == null:
		return Vector3.INF
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := (work_plane_y() - origin.y) / dir.y
	if t <= 0.0:
		return Vector3.INF
	var hit := origin + dir * t
	# Batasi jangkauan tangan.
	var to_cam := hit - camera.global_position
	var flat := Vector3(to_cam.x, 0.0, to_cam.z)
	if flat.length() > REACH:
		hit = camera.global_position + flat.normalized() * REACH
	hit.y = work_plane_y() + 0.04
	return hit


## Tinggi meja kerja (permukaan konter).
func work_plane_y() -> float:
	if session != null and is_instance_valid(session):
		return session.global_position.y
	return 0.92


# --- Resep ---------------------------------------------------------------

## Cek apakah kombinasi objek di tangan memicu langkah resep.
func _evaluate_rules() -> void:
	if session == null:
		return
	var res := RecipeRules.evaluate(left_hand, right_hand)
	if res.is_empty():
		return
	if RecipeRules.apply_step(session, res):
		_refresh_hud()


## Perbarui HUD (harga, status kurang, stok).
func _refresh_hud() -> void:
	if stand == null:
		return
	UILayer.update_prep(stand.snapshot())


# --- Serah terima ke pelanggan -------------------------------------------

## Es jadi -> pelanggan dipanggil ke konter.
func _check_customer(delta: float) -> void:
	if session == null or stand == null:
		return
	var vessel := session.vessel
	if vessel == null:
		return
	var customer := _nearest_customer()
	if customer == null:
		return

	# Panggil pelanggan ke konter begitu es siap.
	if session.is_complete() and not _customer_called:
		_customer_called = true
		customer.come_to_counter(stand.pickup_position())

	var d := customer.global_position.distance_to(stand.pickup_position())
	if d > CUSTOMER_TAKE_DIST:
		return

	if session.is_complete():
		_deliver(customer)
	else:
		# Belum lengkap -> pelanggan komplain what's missing.
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_complain > COMPLAIN_COOLDOWN:
			_last_complain = now
			customer.complain_missing(session.missing_steps())


## Wadah dilepas dekat pelanggan -> serahkan (atau komplain kalau belum lengkap).
func _try_handover(vessel: PrepObject) -> void:
	if vessel == null or session == null:
		return
	var customer := _nearest_customer()
	if customer == null:
		return
	if customer.global_position.distance_to(vessel.global_position) > CUSTOMER_TAKE_DIST:
		return
	if session.is_complete():
		_deliver(customer)
	else:
		customer.complain_missing(session.missing_steps())


## Serahkan es ke pelanggan terdekat (tombol "Serahkan" di HUD).
func deliver_to_nearest_customer() -> void:
	if session == null or stand == null:
		return
	var customer := _nearest_customer()
	if not session.is_complete():
		var missing := session.missing_steps()
		if customer != null:
			customer.complain_missing(missing)
		else:
			UILayer.show_error("Es belum siap. Kurang: %s" % ", ".join(PackedStringArray(missing)))
		return
	if customer == null:
		UILayer.show_error("Belum ada pelanggan di depan meja.")
		return
	customer.come_to_counter(stand.pickup_position())
	_deliver(customer)


## Serahkan es ke pelanggan.
func _deliver(customer: Customer) -> void:
	var bag := session.build_bag()
	if bag == null:
		UILayer.show_error("Stok sachet atau es tidak cukup.")
		return
	stand.offer_bag(bag)
	stand.serve_offered_to(customer)
	# Wadah dikosongkan lagi untuk pesanan berikutnya.
	var vessel := session.vessel
	if vessel != null:
		vessel.reset_contents()
	session.open_build()
	if vessel != null:
		session.set_vessel(vessel)
	_customer_called = false
	_refresh_hud()


## Pelanggan yang sedang menunggu (WAITING) atau yang sudah dipanggil ke
## konter (ARRIVING), paling dekat.
func _nearest_customer() -> Customer:
	var best: Customer = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("customer"):
		var c := node as Customer
		if c == null:
			continue
		if c.state != Customer.State.WAITING and c.state != Customer.State.ARRIVING:
			continue
		var d := c.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = c
	return best
