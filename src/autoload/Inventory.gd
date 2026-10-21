## Inventory.gd
# Global singleton. Plan §Architecture (Inventory) + Task 5.
# Holds money, sachet stock, ice stock, and player-owned tools.
# Implementer Decision #1: ingredients consumed when a Bag is BUILT, not sold.
extends Node

signal stock_changed
signal money_changed(new_money: float)
signal tools_changed

var _money: float = 0.0

var money: float:
	get:
		return _money
	set(v):
		_money = maxf(0.0, v)
		money_changed.emit(_money)

var sachet_stock: Dictionary = {}  # StringName -> int
var ice_stock: int = 0

# Player-owned tools (portable across locations), one per equipment slot.
# quality_mod  = flavor-quality multiplier (startup tools = 1.0; upgrades raise it).
# capacity_mod = spoon capacity contribution (ice_cooler_small => 8; non-coolers => 0).
var owned_tools: Array[Tool] = []


func grant_startup(tools: Array[Tool]) -> void:
	owned_tools = tools.duplicate()
	tools_changed.emit()


func can_afford(price: float) -> bool:
	return _money >= price


func deduct(price: float) -> bool:
	if _money < price:
		return false
	money = _money - price
	return true


func add_money(amount: float) -> void:
	money = _money + amount


func remove_money(amount: float) -> void:
	money = maxf(0.0, _money - amount)


func add_sachets(brand_id: StringName, count: int) -> void:
	sachet_stock[brand_id] = (sachet_stock.get(brand_id, 0) as int) + count
	stock_changed.emit()


func consume_sachet(brand_id: StringName) -> bool:
	var cur := sachet_stock.get(brand_id, 0) as int
	if cur <= 0:
		return false
	sachet_stock[brand_id] = cur - 1
	stock_changed.emit()
	return true


func consume_ice(spoons: int) -> bool:
	if ice_stock < spoons:
		return false
	ice_stock -= spoons
	stock_changed.emit()
	return true


func add_ice(spoons: int) -> void:
	ice_stock += spoons
	stock_changed.emit()


func add_tool(tool: Tool) -> void:
	if not owned_tools.has(tool):
		owned_tools.append(tool)
	tools_changed.emit()


func has_tool(tool_id: StringName) -> bool:
	for t in owned_tools:
		if t.id == tool_id:
			return true
	return false


## The tool currently filling `slot` (or null when the slot is empty).
func tool_in_slot(slot: StringName) -> Tool:
	for t in owned_tools:
		if t.slot == slot:
			return t
	return null


## Install `tool` into its slot, replacing whatever was there.
## Returns the replaced tool, or null when the slot was empty / the tool was
## already installed.
func install_tool(tool: Tool) -> Tool:
	if tool == null:
		return null
	for i in range(owned_tools.size()):
		if owned_tools[i].id == tool.id:
			return null  # already installed
	var previous := tool_in_slot(tool.slot)
	if previous != null:
		owned_tools.erase(previous)
	owned_tools.append(tool)
	tools_changed.emit()
	return previous


## Buy a tool from the shop. Returns true when the purchase went through.
## Fails when the player cannot afford it or already owns the tool.
## A tool that occupies an occupied slot REPLACES the tool that was there.
func buy_tool(tool: Tool) -> bool:
	if tool == null or tool.cost <= 0.0:
		return false
	if has_tool(tool.id):
		return false
	if not can_afford(tool.cost):
		return false
	money = _money - tool.cost  # the setter emits money_changed
	install_tool(tool)
	return true


## Combined quality multiplier across owned tools. The quality mods MULTIPLY,
## so the startup set (1.0 each) gives exactly 1.0 and every upgrade stacks.
func total_quality_mod() -> float:
	var mod := 1.0
	for t in owned_tools:
		mod *= t.quality_mod
	return mod


## Spoon capacity of the cooler in the "cooler" slot (0 when there is none).
func total_ice_capacity() -> int:
	var cooler := tool_in_slot(&"cooler")
	if cooler == null:
		return 0
	return int(cooler.capacity_mod)


# --- Convenience for the prep/serve flow ---


## Probe only — does NOT consume. Use try_consume() to actually spend stock.
func can_make_bag(brand_id: StringName, spoons: int) -> bool:
	return (sachet_stock.get(brand_id, 0) as int) > 0 and ice_stock >= spoons


## Atomically spend one sachet + `spoons` ice spoons.
## All-or-nothing: a bag is never half-built, and a failed build never eats a
## sachet. Implementer Decision #1 — ingredients are consumed on BUILD, not on
## sale, so a wrong-brand refusal still wastes them.
func try_consume(brand_id: StringName, spoons: int) -> bool:
	var sachets := sachet_stock.get(brand_id, 0) as int
	if sachets <= 0:
		return false
	if spoons < 0 or ice_stock < spoons:
		return false
	sachet_stock[brand_id] = sachets - 1
	ice_stock -= spoons
	stock_changed.emit()
	return true


# --- Restock (buy stock with money) ---


## Buy up to `count` sachets of `brand` at its base cost. Returns units bought.
func restock_sachets(brand: SachetBrand, count: int) -> int:
	if brand == null or count <= 0:
		return 0
	var unit := brand.base_cost
	if unit <= 0.0:
		return 0
	var affordable := int(floor(_money / unit))
	var n := mini(count, affordable)
	if n <= 0:
		return 0
	_money -= unit * float(n)
	add_sachets(brand.id, n)
	money_changed.emit(_money)
	return n


## Buy up to `spoons` ice at Bag.ICE_COST_PER_SPOON. Returns spoons bought.
func restock_ice(spoons: int) -> int:
	if spoons <= 0:
		return 0
	var unit := Bag.ICE_COST_PER_SPOON
	if unit <= 0.0:
		return 0
	var affordable := int(floor(_money / unit))
	var n := mini(spoons, affordable)
	if n <= 0:
		return 0
	_money -= unit * float(n)
	ice_stock += n
	stock_changed.emit()
	money_changed.emit(_money)
	return n


func grant_startup_if_empty(start_tools: Array[Tool]) -> void:
	if owned_tools.is_empty():
		grant_startup(start_tools)
