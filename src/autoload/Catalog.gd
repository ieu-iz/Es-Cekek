## Catalog.gd
# Singleton holding the data catalog: LocationDef / SachetBrand / Tool resources.
# Plan §Data Resources + Task 5. Loaded once at boot so every other system
# (PrepStation rack, Customer order picker, StandEquipment) can reach the data
# without re-loading the .tres files.
#
# Registered as an autoload in project.godot BEFORE Inventory, because
# Main/Stand/PrepStation all read from it.
extends Node

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

const STARTUP_TOOL_PATHS: Array[String] = [
	"res://data/tools/table.tres",
	"res://data/tools/sachet_hook.tres",
	"res://data/tools/water_dispenser.tres",
	"res://data/tools/ice_cooler_small.tres",
]

const SHOP_TOOL_PATHS: Array[String] = [
	"res://data/tools/ice_cooler_large.tres",
	"res://data/tools/mixer.tres",
]

var locations: Array[LocationDef] = []
var brands: Array[SachetBrand] = []
var tools: Array[Tool] = []


func _ready() -> void:
	load_catalog()


## Load (or reload) every catalog resource. Safe to call twice.
func load_catalog() -> void:
	locations.clear()
	brands.clear()
	tools.clear()

	for path in LOCATION_PATHS:
		var def := ResourceLoader.load(path) as LocationDef
		if def == null:
			push_error("Catalog: gagal memuat %s" % path)
		else:
			locations.append(def)

	for path in BRAND_PATHS:
		var brand := ResourceLoader.load(path) as SachetBrand
		if brand == null:
			push_error("Catalog: gagal memuat %s" % path)
		else:
			brands.append(brand)

	for path in STARTUP_TOOL_PATHS:
		var tool := ResourceLoader.load(path) as Tool
		if tool == null:
			push_error("Catalog: gagal memuat %s" % path)
		else:
			tools.append(tool)

	for path in SHOP_TOOL_PATHS:
		var tool := ResourceLoader.load(path) as Tool
		if tool == null:
			push_error("Catalog: gagal memuat %s" % path)
		else:
			tools.append(tool)


func brand_by_id(id: StringName) -> SachetBrand:
	for b in brands:
		if b.id == id:
			return b
	return null


func tool_by_id(id: StringName) -> Tool:
	for t in tools:
		if t.id == id:
			return t
	return null


func location_by_id(id: StringName) -> LocationDef:
	for l in locations:
		if l.id == id:
			return l
	return null


## Load a list of tool resources into a TYPED Array[Tool].
## (Array.map() returns an untyped Array in GDScript, so it cannot be handed
##  to a function that expects Array[Tool].)
func _load_tools(paths: Array[String]) -> Array[Tool]:
	var out: Array[Tool] = []
	for path in paths:
		var tool := ResourceLoader.load(path) as Tool
		if tool == null:
			push_error("Catalog: gagal memuat %s" % path)
			continue
		out.append(tool)
	return out


## Startup tools only (free, granted at boot).
func startup_tools() -> Array[Tool]:
	return _load_tools(STARTUP_TOOL_PATHS)


## Shop tools (paid, unlock by day).
func shop_tools() -> Array[Tool]:
	return _load_tools(SHOP_TOOL_PATHS)


## All tools (startup + shop), sorted by unlock_day then cost.
func all_tools() -> Array[Tool]:
	var out := startup_tools()
	for t in shop_tools():
		out.append(t)
	out.sort_custom(func(a: Tool, b: Tool) -> int:
		if a.unlock_day != b.unlock_day:
			return a.unlock_day - b.unlock_day
		return a.cost - b.cost
	)
	return out


## Tools available on day N (startup always; shop tools with unlock_day <= N).
func available_on_day(day: int) -> Array[Tool]:
	var out := startup_tools()
	for t in shop_tools():
		if t.unlock_day <= day:
			out.append(t)
	return out
