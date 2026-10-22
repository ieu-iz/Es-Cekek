## PrepStation.gd
# Task 15 — "mesin resep" (state machine) untuk pembuatan es cekek.
#
# Dulu pipeline ini dipanggil dari tombol panel 2D. Sekarang setiap langkah
# dipicu oleh FISIKA: dua objek yang brought bersama (lihat `RecipeRules.gd`),
# jadi tidak ada tombol untuk brand/volume/air/aduk/es/sedotan lagi.
#
#   potong sachet -> serbuk ke plastik -> air -> aduk -> es (serok) -> sedotan
#
# Quality = brand.base_quality * step_score * tool_mod * 100 (tidak berubah).
# Ingredients are consumed when the bag is BUILT (Implementer Decision #1),
# not when it is sold — so a wrong-brand refusal still wastes them.
class_name PrepStation
extends Node3D

signal bag_built(bag: Bag)
signal prep_changed
## Sinyal bunyi (Task 12 — SFX prosedural, tanpa aset eksternal).
signal pour_done
signal water_added
signal stirred
signal ice_added
signal straw_added

enum State { IDLE, BUILDING, READY }

## Plan tuning table: MAX_SPOON_ICE = 8.
const MAX_SPOON_ICE: int = 8
## Plan §Bag: cost = volume * brand.base_cost + ice * ICE_COST_PER_SPOON.
const MIN_VOLUME: float = 0.5
const MAX_VOLUME: float = 1.0
const VOLUME_STEP: float = 0.1
const ICE_STEP: int = 1
## A serving with 2..6 spoons of ice is "well iced" (full ice score).
const IDEAL_ICE_MIN: int = 2
const IDEAL_ICE_MAX: int = 6

## step_score weights. Must sum to 1.0.
const W_VOLUME: float = 0.25
const W_WATER: float = 0.20
const W_STIR: float = 0.20
const W_ICE: float = 0.25
const W_STRAW: float = 0.10

## Task 15 — urutan langkah yang WAJIB diikuti (resep realistis).
## Langkah yang salah urutan tetap dihitung, tapi dikurangi penalti.
const STEP_ORDER: Array[StringName] = [
	&"cut", &"pour_powder", &"pour_water", &"stir", &"add_ice", &"add_straw",
]
## Penalti quality per langkah yang salah urutan.
const OUT_OF_ORDER_PENALTY: float = 0.70

## Brands available on the rack (filled from the Catalog at runtime).
var rack: Array[SachetBrand] = []

var state: State = State.IDLE
var selected_brand: SachetBrand = null
var volume: float = 0.0
var has_water: bool = false
var has_stir: bool = false
var ice_amount: int = 0
var has_straw: bool = false
var current_bag: Bag = null

## Riwayat langkah yang sudah dilakukan (urutan pemakaiannya).
var step_history: Array[StringName] = []
## Berapa langkah yang dilakukan dengan urutan salah.
var out_of_order_count: int = 0
## Wadah plastik yang sedang diisi (objek fisik di meja).
var vessel: PrepObject = null

var _equipment: StandEquipment = null


func _ready() -> void:
	# Fallback: the stand is the parent node in Stand.tscn.
	if _equipment == null:
		_equipment = get_parent().get_node_or_null("StandEquipment") as StandEquipment


## Wire the stand's equipment so ice capacity / quality mods are read from it.
func set_equipment(equipment: StandEquipment) -> void:
	_equipment = equipment


func equipment() -> StandEquipment:
	return _equipment


## Fill the rack with the catalog brands (called by the Stand on spawn).
func set_rack(brands: Array[SachetBrand]) -> void:
	rack.clear()
	for b in brands:
		rack.append(b)


## Max ice spoons this station can serve. It is driven by the cooler that is
## fitted on the stand (ice_cooler_small => 8, ice_cooler_large => 16). When the
## stand has no equipment wired up, the plan's MAX_SPOON_ICE is used.
func ice_capacity() -> int:
	if _equipment == null:
		return MAX_SPOON_ICE
	var cap := _equipment.ice_capacity()
	if cap <= 0:
		return MAX_SPOON_ICE
	return cap


## Tool quality multiplier (startup set => 1.0).
func tool_quality_mod() -> float:
	if _equipment == null:
		return 1.0
	return _equipment.quality_mod()


# --- Pipeline ------------------------------------------------------------

## Start a fresh build. Discards any half-finished bag (ingredients of a
## half-finished bag are NOT consumed — only a finished build spends stock).
func open_build() -> void:
	reset()
	state = State.BUILDING
	prep_changed.emit()


func reset() -> void:
	state = State.IDLE
	selected_brand = null
	volume = 0.0
	has_water = false
	has_stir = false
	ice_amount = 0
	has_straw = false
	current_bag = null
	step_history.clear()
	out_of_order_count = 0
	vessel = null


func select_brand(brand: SachetBrand) -> void:
	if brand == null:
		return
	selected_brand = brand
	prep_changed.emit()


## Pour the sachet. `amount` is the resulting volume (0..1).
func pour(amount: float) -> void:
	volume = clampf(amount, 0.0, MAX_VOLUME)
	pour_done.emit()
	prep_changed.emit()


func add_volume(delta: float) -> void:
	pour(volume + delta)


func add_water() -> void:
	has_water = true
	water_added.emit()
	prep_changed.emit()


func stir() -> void:
	has_stir = true
	stirred.emit()
	prep_changed.emit()


## Add ice spoons, capped by the stand's ice capacity (the fitted cooler).
func add_ice(spoons: int) -> void:
	var cap := ice_capacity()
	if cap <= 0:
		ice_amount = 0
	else:
		ice_amount = clampi(ice_amount + spoons, 0, cap)
	ice_added.emit()
	prep_changed.emit()


func add_straw() -> void:
	has_straw = true
	straw_added.emit()
	prep_changed.emit()


# --- Resep (Task 15) -----------------------------------------------------

## Catat langkah yang sudah dilakukan. Kalau langkahnya mendahului langkah
## wajib berikutnya, itu dihitung sebagai "salah urutan" (penalti quality).
## Mengembalikan true kalau ini langkah baru.
func record_step(step: StringName) -> bool:
	if step_history.has(step):
		return false
	var expected := expected_next_step()
	if step != expected:
		out_of_order_count += 1
	step_history.append(step)
	prep_changed.emit()
	return true


## Apakah langkah ini sudah dilakukan?
func has_step(step: StringName) -> bool:
	return step_history.has(step)


## Langkah wajib berikutnya (kalau semua sudah, hasilnya kosong).
func expected_next_step() -> StringName:
	for s in STEP_ORDER:
		if not step_history.has(s):
			return s
	return &""


## Apakah resepnya sudah lengkap (semua bahan ada)?
func is_complete() -> bool:
	return volume > 0.0 and has_water and has_stir and ice_amount > 0 and has_straw


## Daftar yang masih kurang — dipakai sebagai komplain pelanggan.
func missing_steps() -> Array[String]:
	var out: Array[String] = []
	if selected_brand == null:
		out.append("Belum ambil sachet!")
	if volume <= 0.0:
		out.append("Belum ada serbub sachet!")
	if not has_water:
		out.append("Belum dikasih air!")
	if not has_stir:
		out.append("Belum diaduk!")
	if ice_amount <= 0:
		out.append("Belum ada es!")
	if not has_straw:
		out.append("Belum ada sedotannya!")
	return out


## Set wadah plastik yang sedang diisi.
func set_vessel(obj: PrepObject) -> void:
	vessel = obj


# --- Scoring -------------------------------------------------------------

## Weighted correctness of the steps, 0..1.
func step_score() -> float:
	var score := 0.0

	# Volume: full marks from MIN_VOLUME upwards, zero below 0.5.
	var vol_score := clampf((volume - MIN_VOLUME) / (MAX_VOLUME - MIN_VOLUME), 0.0, 1.0)
	score += W_VOLUME * vol_score

	if has_water:
		score += W_WATER
	if has_stir:
		score += W_STIR

	# Ice: 2..6 spoons is well iced, any other non-zero amount is half credit.
	var ice_score := 0.0
	if ice_amount >= IDEAL_ICE_MIN and ice_amount <= IDEAL_ICE_MAX:
		ice_score = 1.0
	elif ice_amount > 0:
		ice_score = 0.5
	score += W_ICE * ice_score

	if has_straw:
		score += W_STRAW

	# Langkah salah urutan mengurangi kualitas.
	if out_of_order_count > 0:
		score *= pow(OUT_OF_ORDER_PENALTY, float(out_of_order_count))

	return clampf(score, 0.0, 1.0)


## prep_quality = base_quality * step_score * tool_mod, scaled to 0..100.
func compute_prep_quality() -> int:
	if selected_brand == null:
		return 0
	var base := selected_brand.base_quality
	var score := step_score()
	var tmod := tool_quality_mod()
	return clampi(roundi(base * score * tmod * 100.0), 0, 100)


## What the finished bag would cost the player.
func estimated_cost() -> float:
	if selected_brand == null:
		return 0.0
	return volume * selected_brand.base_cost + ice_amount * Bag.ICE_COST_PER_SPOON


## Can the current build be turned into a bag? Needs a brand and enough stock.
func can_build() -> bool:
	if selected_brand == null:
		return false
	return Inventory.can_make_bag(selected_brand.id, ice_amount)


## Build the bag. Consumes 1 sachet + the ice spoons from the Inventory.
## Returns the bag, or null when there is no brand / not enough stock.
func build_bag() -> Bag:
	if selected_brand == null:
		return null
	if not Inventory.try_consume(selected_brand.id, ice_amount):
		return null

	var portion := SachetPortion.new()
	portion.brand = selected_brand
	portion.volume = maxf(volume, 0.05)

	var portions: Array[SachetPortion] = []
	portions.append(portion)

	var bag := Bag.new()
	bag.portions = portions
	bag.ice_amount = ice_amount
	bag.prep_quality = compute_prep_quality()
	bag.sell_price = bag.recommended_price()
	bag.has_straw = has_straw

	current_bag = bag
	state = State.READY
	bag_built.emit(bag)
	prep_changed.emit()
	return bag


## Throw the current bag away (wrong brand -> refuse path wastes the bag).
func discard_bag() -> void:
	current_bag = null
	state = State.IDLE
	prep_changed.emit()


## Snapshot of the current build for the UI.
func snapshot() -> Dictionary:
	return {
		"state": state,
		"brand": selected_brand.display_name if selected_brand != null else "-",
		"brand_id": selected_brand.id if selected_brand != null else &"",
		"volume": volume,
		"water": has_water,
		"stir": has_stir,
		"ice": ice_amount,
		"straw": has_straw,
		"quality": compute_prep_quality() if selected_brand != null else 0,
		"cost": estimated_cost(),
		"ice_capacity": ice_capacity(),
		"can_build": can_build(),
		"complete": is_complete(),
		"steps_done": step_history.size(),
		"out_of_order": out_of_order_count,
		"missing": missing_steps(),
	}
