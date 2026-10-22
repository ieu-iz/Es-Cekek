## Customer.gd
# Plan §Customer (scene) + §Customer serve + §Annoyance escalation. Task 7.
#
# A customer:
#   1. spawns, walks to a seat (or joins the queue),
#   2. orders a brand (weighted by SachetBrand.rarity),
#   3. gets annoyed while waiting (rate scales with LocationDef.annoyance_rate),
#   4. is served a Bag -> satisfaction / tip / refuse.
#
# Implementer Decision: annoyance NEVER expels the customer. They complain
# louder and crouch, but they stay in line.
class_name Customer
extends Node3D

signal complain(line: String, annoyance: float)
signal served(result: Dictionary)
signal left_the_stand

enum State { ARRIVING, WAITING, SERVED, LEAVING }

## Plan tuning table: TIP_MULTIPLIER = 0.4.
const TIP_MULTIPLIER: float = 0.4
## Plan tuning table: PRICE_COMPLAIN_AT = 1.5 (x cost).
## The plan's tuning table and validation plan both express this as a multiple
## of the bag cost, so that is what is used here.
const PRICE_COMPLAIN_AT: float = 1.5
## Plan tuning table: ANNOYANCE_MAX_WAIT = ~45 seconds.
const ANNOYANCE_MAX_WAIT: float = 45.0
## Plan tuning table: ANNOYANCE_TIERS = 0.30 / 0.60 / 0.85 / 1.00.
const ANNOYANCE_TIERS: Array[float] = [0.30, 0.60, 0.85, 1.00]
## Complaint lines per annoyance tier.
const COMPLAIN_LINES: Array[String] = [
	"Lama amat, bang…",
	"Mau es apa berak bang?",
	"Wah, pelanggan lain mah cepat-cepat…",
	"Berhenti main HP, bang!",
]
const WRONG_BRAND_LINE: String = "Ini bukan %s, bang!"
const OVERPRICE_LINE: String = "Mahal amat!"
const THANK_YOU_LINE: String = "Makasih, bang!"

## Brand this customer ordered.
@export var order_brand: SachetBrand = null
## Ke mana pelanggan ini harus menoleh saat menunggu (posisi vendor/stand).
## Vector3.ZERO = tidak menoleh ke mana-mana.
var face_target: Vector3 = Vector3.ZERO
## Highest price this customer is comfortable with (0.7..0.85 x fair_max).
@export var price_tolerance: float = 0.0
## Walk speed in m/s.
@export var walk_speed: float = 2.2

var annoyance_level: float = 0.0
var state: State = State.ARRIVING
var is_seated: bool = false
var slot_index: int = -1
## Scales how fast annoyance rises (from LocationDef.annoyance_rate).
var annoyance_rate: float = 1.0
## Complaint lines — exposed so they can be swapped per location later.
var complain_lines: Array[String] = COMPLAIN_LINES.duplicate()
var last_complaint_tier: int = -1
var target_position: Vector3 = Vector3.ZERO
var exit_position: Vector3 = Vector3.ZERO

var _arrived: bool = false

# --- Visual 3D (Task 12) -------------------------------------------------

## Lama bubble keluhan tetap tampil (detik).
const BUBBLE_TIME: float = 2.4
## Warna dasar badan (harus sama dengan Customer.tscn).
const BODY_COLOR := Color(0.42, 0.55, 0.78)
## Warna badan saat pelanggan sangat kesal.
const BODY_ANGRY_COLOR := Color(0.85, 0.25, 0.25)
## Kecepatan pelanggan berputar menoleh ke vendor (radian per detik-ish).
const TURN_SPEED: float = 8.0
## Tinggi kepala karakter Kenney (dipakai proxy Head).
const HEAD_HEIGHT: float = 1.45

@onready var body: Node3D = get_node_or_null("Body")
@onready var head: Node3D = get_node_or_null("Head")
@onready var bubble: Label3D = get_node_or_null("Bubble")
## Model karakter Kenney (anak dari node Body, jadi ikut memendek saat kesal).
@onready var character: KenneyCharacter = get_node_or_null("Body/Character")

## Sisa waktu bubble (detik).
var _bubble_timer: float = 0.0
## Jongkok saat ini (0 = berdiri, 1 = jongkok dalam).
var _crouch: float = 0.0


func _ready() -> void:
	add_to_group("customer")
	# Material badan diduplikasi supaya tiap pelanggan bisa punya warna kesal
	# sendiri tanpa mengubah pelanggan lain.
	if body != null and body.material_override != null:
		body.material_override = body.material_override.duplicate()
	# Bubble keluhan mengikuti sinyal complain.
	if not complain.is_connected(_on_complain):
		complain.connect(_on_complain)
	apply_pose(0.0)


## Called by the spawner right after instantiation.
func setup(brand: SachetBrand, rate: float) -> void:
	order_brand = brand
	annoyance_rate = maxf(rate, 0.0)
	if order_brand != null:
		# fair_max for a full serving without ice, times the random tolerance.
		price_tolerance = order_brand.base_cost * Bag.FAIR_PROFIT_MAX * randf_range(0.7, 0.85)


func _process(delta: float) -> void:
	update_feedback(delta)
	match state:
		State.ARRIVING:
			_walk_towards(target_position, delta)
			if global_position.distance_to(target_position) < 0.2:
				state = State.WAITING
				_arrived = true
				if character != null:
					character.set_moving(false)
		State.WAITING:
			_tick_annoyance(delta)
			_face_stand(delta)
		State.LEAVING:
			_walk_towards(exit_position, delta)
			if global_position.distance_to(exit_position) < 0.4:
				left_the_stand.emit()
				queue_free()
		State.SERVED:
			pass


## Pelanggan yang sedang menunggu menoleh ke arah vendor/stand.
func _face_stand(delta: float) -> void:
	if face_target == Vector3.ZERO:
		return
	var to_target := face_target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.05:
		return
	var target_yaw := atan2(-to_target.x, -to_target.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(TURN_SPEED * delta, 1.0))


func _walk_towards(target: Vector3, delta: float) -> void:
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.05:
		return
	var step := to_target.normalized() * walk_speed * delta
	global_position += step
	# Animasi jalan (asset Kenney: jalan di tempat, node yang digerakkan manual).
	if character != null:
		character.set_moving(true)
	# Face the direction of travel.
	if absf(to_target.x) > 0.01 or absf(to_target.z) > 0.01:
		rotation.y = atan2(-to_target.x, -to_target.z)


# --- Visual 3D (Task 12) -------------------------------------------------

## Update semua feedback visual: bubble keluhan + pose kesal.
func update_feedback(delta: float) -> void:
	# Bubble disembunyikan setelah BUBBLE_TIME.
	if bubble != null and bubble.visible:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			hide_bubble()
	# Pose bergerak halus ke arah target.
	var target := target_crouch()
	_crouch = move_toward(_crouch, target, delta * 2.0)
	apply_pose(_crouch)


## Seberapa jongkok pelanggan ini, 0..1, berdasarkan tingkat kesal.
func target_crouch() -> float:
	if state == State.SERVED or state == State.LEAVING:
		return 0.0
	if annoyance_level >= ANNOYANCE_TIERS[3]:
		return 1.0
	if annoyance_level >= ANNOYANCE_TIERS[2]:
		return 0.75
	if annoyance_level >= ANNOYANCE_TIERS[1]:
		return 0.5
	if annoyance_level >= ANNOYANCE_TIERS[0]:
		return 0.25
	return 0.0


## Terapkan pose kesal. `crouch` 0..1: badan memendek, kepala menunduk,
## dan badan makin kemerahan.
func apply_pose(crouch: float) -> void:
	var c := clampf(crouch, 0.0, 1.0)
	var squash := 1.0 - 0.35 * c
	if body != null:
		# Node Body adalah induk model karakter Kenney, jadi skala Y di sini
		# benar-benar memendekkan karakter (bukan hanya proxy).
		body.scale = Vector3(1.0, squash, 1.0)
		body.position = Vector3.ZERO
		var mat := body.material_override as StandardMaterial3D
		if mat != null:
			var tint := BODY_COLOR.lerp(BODY_ANGRY_COLOR, c * 0.8)
			# Alpha tetap (proxy body tidak boleh jadi terlihat).
			mat.albedo_color = Color(tint.r, tint.g, tint.b, mat.albedo_color.a)
	if head != null:
		head.position = Vector3(0.0, HEAD_HEIGHT * squash, 0.0)
		# Makin kesal -> kepala makin menunduk.
		head.rotation.x = deg_to_rad(20.0 * c)
	if character != null:
		# Model asli: badan makin merah + badan condong ke depan.
		character.set_annoyance(c)


## Tampilkan bubble keluhan di atas kepala pelanggan.
func show_bubble(line: String) -> void:
	if bubble == null or line == "":
		return
	bubble.text = line
	bubble.visible = true
	_bubble_timer = BUBBLE_TIME


## Sembunyikan bubble keluhan.
func hide_bubble() -> void:
	if bubble == null:
		return
	bubble.visible = false
	bubble.text = ""
	_bubble_timer = 0.0


func _on_complain(line: String, _annoyance: float) -> void:
	show_bubble(line)
	# Bunyi keluhan (Task 12 — SFX prosedural).
	Audio.play(&"complain")


# --- Annoyance ----------------------------------------------------------

func _tick_annoyance(delta: float) -> void:
	# Busier locations have a higher annoyance_rate, so the wait feels shorter.
	annoyance_level = clampf(
		annoyance_level + delta * (annoyance_rate / ANNOYANCE_MAX_WAIT),
		0.0, 1.0
	)

	# Pick the HIGHEST tier that was crossed and not complained about yet, so
	# a long wait jumps straight to the most severe line.
	var crossed := -1
	for i in range(ANNOYANCE_TIERS.size()):
		if annoyance_level >= ANNOYANCE_TIERS[i] and i > last_complaint_tier:
			crossed = i
	if crossed < 0:
		return
	last_complaint_tier = crossed
	var line := ""
	if crossed < complain_lines.size():
		line = complain_lines[crossed]
	complain.emit(line, annoyance_level)
	UILayer.show_complain(line, annoyance_level)


## Force the annoyance up (used by the wrong-brand refuse path).
func add_annoyance(amount: float) -> void:
	annoyance_level = clampf(annoyance_level + amount, 0.0, 1.0)


# --- Task 15: first-person hands ----------------------------------------

## Dipanggil saat es siap: pelanggan berjalan ke konter untuk mengambilnya.
func come_to_counter(pos: Vector3) -> void:
	if state == State.SERVED or state == State.LEAVING:
		return
	target_position = pos
	_arrived = false
	state = State.ARRIVING
	if character != null:
		character.set_moving(true)


## Komplain karena es yang diserahkan belum lengkap. `missing` berisi
## daftar langkah yang belum dilakukan (lihat `PrepStation.missing_steps`).
func complain_missing(missing: Array) -> void:
	var parts := PackedStringArray()
	for m in missing:
		parts.append(str(m))
	var line := "Kurang: " + ", ".join(parts)
	complain.emit(line, annoyance_level)
	UILayer.show_complain(line, annoyance_level)


# --- Serve evaluation ----------------------------------------------------

## Evaluate serving `bag` to this customer.
## Returns a dictionary with:
##   accepted    — did the customer take the drink?
##   refused     — wrong brand (no pay, bag wasted)
##   satisfaction — 0..1
##   tip         — extra money paid
##   total_paid  — sell_price + tip
##   line        — what the customer says
func evaluate_serve(bag: Bag) -> Dictionary:
	if bag == null or bag.is_empty():
		return {
			"ok": true,
			"accepted": false,
			"refused": false,
			"satisfaction": 0.0,
			"tip": 0.0,
			"total_paid": 0.0,
			"line": "Esnya mana, bang?",
		}

	var brand := bag.primary_brand()

	# --- Refuse gate: wrong brand only. Never refuses on price. ---
	if brand == null or order_brand == null or brand.id != order_brand.id:
		add_annoyance(0.2)
		var wanted := order_brand.display_name if order_brand != null else "yang lain"
		var line := WRONG_BRAND_LINE % wanted
		complain.emit(line, annoyance_level)
		UILayer.show_complain(line, annoyance_level)
		return {
			"ok": true,
			"accepted": false,
			"refused": true,
			"satisfaction": 0.0,
			"tip": 0.0,
			"total_paid": 0.0,
			"line": line,
		}

	# --- Right brand: score the drink ---
	var portion_volume := 1.0
	if bag.portions.size() > 0:
		portion_volume = bag.portions[0].volume
	var taste_fit := 1.0 if (portion_volume >= 0.5 and portion_volume <= 1.0) else 0.6
	var satisfaction := clampf(
		(bag.prep_quality / 100.0) * taste_fit * (1.0 - 0.6 * annoyance_level),
		0.0, 1.0
	)

	var cost := bag.cost()
	var price_ratio := 0.0
	if cost > 0.0:
		price_ratio = bag.sell_price / cost

	# Tip is lost above PRICE_COMPLAIN_AT x cost, but the customer still pays.
	var tip := 0.0
	if price_ratio <= PRICE_COMPLAIN_AT:
		tip = satisfaction * TIP_MULTIPLIER * bag.sell_price

	var total_paid := bag.sell_price + tip

	var line := THANK_YOU_LINE
	if price_ratio > PRICE_COMPLAIN_AT or (price_tolerance > 0.0 and bag.sell_price > price_tolerance):
		line = OVERPRICE_LINE
		complain.emit(line, annoyance_level)
		UILayer.show_complain(line, annoyance_level)

	state = State.SERVED
	var result := {
		"ok": true,
		"accepted": true,
		"refused": false,
		"satisfaction": satisfaction,
		"tip": tip,
		"total_paid": total_paid,
		"price_ratio": price_ratio,
		"line": line,
	}
	served.emit(result)
	return result


## Walk away from the stand (after a successful serve).
func leave(exit_point: Vector3) -> void:
	exit_position = exit_point
	state = State.LEAVING
