## CustomerSpawner.gd
# Plan Task 7: spawns customers for the current location, hands them a seat or
# a queue slot, and pauses spawning when the stand is full.
#
# Implementer Decision: the stand never expels customers, so the only way to
# stop the stand from clogging is a hard cap (seats + max_queue) and a spawn
# pause while the cap is reached.
class_name CustomerSpawner
extends Node3D

const CUSTOMER_SCENE_PATH: String = "res://src/entities/Customer.tscn"

## Base seconds between spawns at foot_traffic = 1.0.
@export var base_spawn_interval: float = 9.0
## How far from the stand customers appear.
@export var spawn_distance: float = 8.0

var location_def: LocationDef = null
var stand: Stand = null
var brands: Array[SachetBrand] = []
var customers: Array[Customer] = []

var _timer: float = 0.0
var _spawn_count: int = 0


## Wire the spawner to the location it belongs to.
func setup(def: LocationDef, stand_ref: Stand, brand_list: Array[SachetBrand]) -> void:
	location_def = def
	stand = stand_ref
	brands.clear()
	for b in brand_list:
		brands.append(b)
	_timer = base_spawn_interval * 0.4


## Seconds between spawns. Busier locations (higher foot_traffic) spawn more.
func spawn_interval() -> float:
	if location_def == null:
		return base_spawn_interval
	return base_spawn_interval / maxf(location_def.foot_traffic, 0.05)


func _process(delta: float) -> void:
	if location_def == null or stand == null or brands.is_empty():
		return

	_timer -= delta
	if _timer > 0.0:
		return

	if try_spawn():
		_timer = spawn_interval()
	else:
		# Stand is full: pause spawning (documented guard) and retry soon.
		_timer = 1.0


## Try to spawn one customer. Returns false when the stand is at capacity.
func try_spawn() -> bool:
	if stand == null or brands.is_empty():
		return false

	var seats := stand.seat_positions()
	var queue := stand.queue_positions()
	var seat_limit := mini(location_def.seats, seats.size())
	var queue_limit := mini(location_def.max_queue, queue.size())

	var seated := 0
	var queued := 0
	for c in customers:
		if c == null or not is_instance_valid(c):
			continue
		if c.state == Customer.State.LEAVING or c.state == Customer.State.SERVED:
			continue
		if c.is_seated:
			seated += 1
		else:
			queued += 1

	var target := Vector3.ZERO
	var seat_index := -1
	if seated < seat_limit:
		seat_index = seated
		target = seats[seat_index]
	elif queued < queue_limit:
		target = queue[queued]
	else:
		# Beyond seats + queue -> spawns pause until someone is served.
		return false

	var scene := load(CUSTOMER_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("CustomerSpawner: %s tidak ditemukan." % CUSTOMER_SCENE_PATH)
		return false
	var customer := scene.instantiate() as Customer
	if customer == null:
		return false

	var brand := _pick_brand()
	customer.setup(brand, location_def.annoyance_rate)
	customer.is_seated = seat_index >= 0
	customer.slot_index = seat_index if seat_index >= 0 else queued
	# Pelanggan menunggu sambil menoleh ke arah vendor (posisi servis stand).
	if stand != null:
		customer.face_target = stand.service_position()

	add_child(customer)
	customer.global_position = _spawn_position()
	customer.target_position = target
	customers.append(customer)
	_spawn_count += 1

	# Announce the order on the HUD.
	if brand != null:
		UILayer.show_order(brand.display_name)
	return true


## Weighted pick by SachetBrand.rarity (rarer brands are ordered less often).
func _pick_brand() -> SachetBrand:
	if brands.is_empty():
		return null
	var total := 0.0
	for b in brands:
		total += maxf(b.rarity, 0.01)
	var roll := randf() * total
	for b in brands:
		roll -= maxf(b.rarity, 0.01)
		if roll <= 0.0:
			return b
	return brands[brands.size() - 1]


func _spawn_position() -> Vector3:
	var base := stand.global_position if stand != null else global_position
	var angle := randf() * TAU
	return base + Vector3(cos(angle) * spawn_distance, 0.0, sin(angle) * spawn_distance)


## Remove a customer from the tracking list (called when they leave).
func forget(customer: Customer) -> void:
	customers.erase(customer)


## How many customers are currently waiting (seated + queue).
func waiting_count() -> int:
	var n := 0
	for c in customers:
		if c == null or not is_instance_valid(c):
			continue
		if c.state == Customer.State.ARRIVING or c.state == Customer.State.WAITING:
			n += 1
	return n


## The customer that should be served next (first in line).
func next_customer() -> Customer:
	for c in customers:
		if c == null or not is_instance_valid(c):
			continue
		if c.state == Customer.State.WAITING:
			return c
	return null


func clear_customers() -> void:
	for c in customers:
		if c != null and is_instance_valid(c):
			c.queue_free()
	customers.clear()
