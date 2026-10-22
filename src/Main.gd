## Main.gd
# Persistent bootstrap. Lives for the whole session (survives location loads).
# Plan §Architecture (Main) + Task 1/4.
#
# Responsibilities:
#   - Load the data catalog (locations / brands / tools) from res://data/
#   - Hand the catalog to the singletons (LocationManager, Inventory)
#   - Load the first location, start the day loop, wire the day cycle
extends Node3D

## Starting capital. Plan §Economy: player begins with enough to buy stock.
const STARTING_MONEY: float = 50000.0
## Sachets of every brand the player starts with.
const STARTING_SACHETS_PER_BRAND: int = 20
## Ice spoons in the cooler at the start of each day.
const STARTING_ICE: int = 40

@onready var world_root: Node3D = $WorldRoot
@onready var player: CharacterBody3D = $Player
## Matahari persisten (grup "sun") — milik Main, bukan tiap lokasi.
@onready var sun: DirectionalLight3D = $Sun
## Lingkungan dunia persisten (langit + ambient + kabut).
@onready var world_environment: WorldEnvironment = $WorldEnvironment

## The data catalog lives in the Catalog autoload (res://src/autoload/Catalog.gd).
var location_defs: Array[LocationDef]:
	get:
		return Catalog.locations

var brands: Array[SachetBrand]:
	get:
		return Catalog.brands

var tools: Array[Tool]:
	get:
		return Catalog.tools


func _ready() -> void:
	world_root.add_to_group("world_root")

	if Catalog.locations.is_empty():
		Catalog.load_catalog()
	if location_defs.is_empty():
		push_error("Main: tidak ada LocationDef yang termuat — game tidak bisa jalan.")
		return

	LocationManager.set_locations(location_defs)
	UILayer.set_locations(location_defs)
	_setup_inventory()
	_wire_signals()

	# Serahkan matahari + lingkungan dunia ke TimeOfDay supaya siklus
	# siang/malam benar-benar mengubah pencahayaan.
	TimeOfDay.sun_light = sun
	TimeOfDay.environment = world_environment

	# First location = Pasar (busiest). Plan Task 4.
	LocationManager.load_location(world_root, location_defs[0])
	TimeOfDay.start_day(Economy.current_day)
	UILayer.update_hud(Inventory.money, Economy.current_day, 0.0)


# --- Inventory setup ---------------------------------------------------

func _setup_inventory() -> void:
	# Startup tools only: table, sachet_hook, water_dispenser, ice_cooler_small.
	# Shop tools (ice_cooler_large, mixer) are bought from the shop during the
	# day — they cost money and unlock by day.
	Inventory.grant_startup(Catalog.startup_tools())
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
	Inventory.tools_changed.connect(_on_tools_changed)
	UILayer.travel_requested.connect(_on_travel_requested)
	UILayer.day_end_continue.connect(_on_day_end_continue)
	UILayer.interact_pressed.connect(_on_interact_pressed)
	UILayer.shop_action.connect(_on_shop_action)


func _on_day_ended(_day: int) -> void:
	Economy.end_day()


func _on_day_started(day: int) -> void:
	TimeOfDay.start_day(day)
	# Restock ice for the new day (sachets are bought with money).
	Inventory.add_ice(STARTING_ICE)
	UILayer.update_hud(Inventory.money, day, 0.0)
	# New shop stock may have unlocked overnight.
	UILayer.refresh_shop()


func _on_day_completed(recap: Dictionary) -> void:
	print("[Main] rekap hari %s: omset %s / laba %s" % [
		recap.get("day", 0), recap.get("revenue", 0), recap.get("profit", 0)
	])


func _on_money_changed(new_money: float) -> void:
	UILayer.update_hud(new_money, Economy.current_day, TimeOfDay.elapsed_seconds())
	# The shop buttons grey out when the money runs short.
	UILayer.refresh_shop()


func _on_tools_changed() -> void:
	# A tool was bought or replaced — refresh the shop so the buttons update.
	UILayer.refresh_shop()


## Handle a shop panel action (Task 8).
func _on_shop_action(action: StringName, value: float) -> void:
	if action == UILayer.SHOP_ACTION_BUY_TOOL:
		UILayer.buy_tool_at(int(value))
	elif action == UILayer.SHOP_ACTION_CLOSE:
		UILayer.close_shop()


func _on_travel_requested(location_id: StringName) -> void:
	LocationManager.travel_to(location_id)


func _on_interact_pressed() -> void:
	# The on-screen INTERAK button. The Player owns the interaction logic.
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("_interact"):
			p.call("_interact")


func _on_day_end_continue() -> void:
	# Economy.end_day() already advanced the day and emitted day_started,
	# which restarted TimeOfDay. Nothing else to do here.
	pass
