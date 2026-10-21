## Main.gd
# Persistent bootstrap. Lives for the whole session (survives location loads).
# Plan §Architecture (Main) + Task 1/4.
#
# Responsibilities:
#   - Load the data catalog (locations / brands / tools) from res://data/
#   - Hand the catalog to the singletons (LocationManager, Inventory)
#   - Load the first location, start the day loop, wire the day cycle
extends Node3D

const LOCATION_PATHS: Array[String] = [
	"res://data/locations/pasar.tres",
	"res://data/locations/sekolah.tres",
	"res://data/locations/rumah.tres",
]

const BRAND_PATHS: Array[String] = [
	"res://data/brands/tejus.tres",
	"res://data/brands/marimas.tres",
	"res://data/brands/jasjus.tres",
	"res://data/brands/frenta.tres",
]

const TOOL_PATHS: Array[String] = [
	"res://data/tools/table.tres",
	"res://data/tools/sachet_hook.tres",
	"res://data/tools/water_dispenser.tres",
	"res://data/tools/ice_cooler_small.tres",
]

## Starting capital. Plan §Economy: player begins with enough to buy stock.
const STARTING_MONEY: float = 50000.0
## Sachets of every brand the player starts with.
const STARTING_SACHETS_PER_BRAND: int = 20
## Ice spoons in the cooler at the start of each day.
const STARTING_ICE: int = 40

@onready var world_root: Node3D = $WorldRoot
@onready var player: CharacterBody3D = $Player

var location_defs: Array[LocationDef] = []
var brands: Array[SachetBrand] = []
var tools: Array[Tool] = []


func _ready() -> void:
	world_root.add_to_group("world_root")

	_load_catalog()
	if location_defs.is_empty():
		push_error("Main: tidak ada LocationDef yang termuat — game tidak bisa jalan.")
		return

	LocationManager.set_locations(location_defs)
	UILayer.set_locations(location_defs)
	_setup_inventory()
	_wire_signals()

	# First location = Pasar (busiest). Plan Task 4.
	LocationManager.load_location(world_root, location_defs[0])
	TimeOfDay.start_day(Economy.current_day)
	UILayer.update_hud(Inventory.money, Economy.current_day, 0.0)
	UILayer.show_order("Tejus")


# --- Catalog ------------------------------------------------------------

func _load_catalog() -> void:
	for path in LOCATION_PATHS:
		var def := ResourceLoader.load(path) as LocationDef
		if def == null:
			push_error("Main: gagal memuat %s" % path)
		else:
			location_defs.append(def)

	for path in BRAND_PATHS:
		var brand := ResourceLoader.load(path) as SachetBrand
		if brand == null:
			push_error("Main: gagal memuat %s" % path)
		else:
			brands.append(brand)

	for path in TOOL_PATHS:
		var tool := ResourceLoader.load(path) as Tool
		if tool == null:
			push_error("Main: gagal memuat %s" % path)
		else:
			tools.append(tool)


func _setup_inventory() -> void:
	# Startup tools: table, sachet_hook, water_dispenser, ice_cooler_small.
	Inventory.grant_startup(tools)
	Inventory.money = STARTING_MONEY
	Inventory.add_ice(STARTING_ICE)
	for brand in brands:
		Inventory.add_sachets(brand.id, STARTING_SACHETS_PER_BRAND)


# --- Signals ------------------------------------------------------------

func _wire_signals() -> void:
	TimeOfDay.day_ended.connect(_on_day_ended)
	Economy.day_started.connect(_on_day_started)
	Economy.day_completed.connect(_on_day_completed)
	Inventory.money_changed.connect(_on_money_changed)
	UILayer.travel_requested.connect(_on_travel_requested)
	UILayer.day_end_continue.connect(_on_day_end_continue)
	UILayer.interact_pressed.connect(_on_interact_pressed)


func _on_day_ended(_day: int) -> void:
	Economy.end_day()


func _on_day_started(day: int) -> void:
	TimeOfDay.start_day(day)
	# Restock ice for the new day (sachets are bought with money in Task 5 UI).
	Inventory.add_ice(STARTING_ICE)
	UILayer.update_hud(Inventory.money, day, 0.0)


func _on_day_completed(recap: Dictionary) -> void:
	print("[Main] rekap hari %s: omset %s / laba %s" % [
		recap.get("day", 0), recap.get("revenue", 0), recap.get("profit", 0)
	])


func _on_money_changed(new_money: float) -> void:
	UILayer.update_hud(new_money, Economy.current_day, TimeOfDay.elapsed_seconds())


func _on_travel_requested(location_id: StringName) -> void:
	LocationManager.travel_to(location_id)


func _on_interact_pressed() -> void:
	pass


func _on_day_end_continue() -> void:
	# Economy.end_day() already advanced the day and emitted day_started,
	# which restarted TimeOfDay. Nothing else to do here.
	pass
