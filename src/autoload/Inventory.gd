## Inventory.gd
# Global singleton. Plan §Architecture (Inventory) + Task 5.
# Holds money, sachet stock, ice stock, and player-owned tools.
# Implementer Decision #1: ingredients consumed when a Bag is BUILT, not sold.
extends Node

signal stock_changed
signal money_changed(new_money: float)
signal tools_changed

var money: float = 0.0:
	set(v):
		money = v
		money_changed.emit(money)

var sachet_stock: Dictionary = {}  # StringName -> int
var ice_stock: int = 0

# Player-owned tools (portable across locations).
# quality_mod  = flavor-quality multiplier (startup tools = 1.0; upgrades raise it).
# capacity_mod = spoon capacity contribution (ice_cooler_small => 8; non-coolers => 0).
var owned_tools: Array[Tool] = []


func grant_startup(tools: Array[Tool]) -> void:
	owned_tools = tools.duplicate()
	tools_changed.emit()


func can_afford(price: float) -> bool:
	return money >= price


func deduct(price: float) -> bool:
	if money < price:
		return false
	money -= price
	return true


func add_money(amount: float) -> void:
	money += amount
	money_changed.emit(money)


func remove_money(amount: float) -> void:
	money = maxf(0.0, money - amount)
	money_changed.emit(money)


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


# Average quality modifier across owned tools (startup = 1.0).
func total_quality_mod() -> float:
	if owned_tools.is_empty():
		return 1.0
	var total := 0.0
	for t in owned_tools:
		total += t.quality_mod
	return total / owned_tools.size()


# Sum of spoon-capacity contributions (startup ice_cooler_small => 8).
func total_ice_capacity() -> int:
	var cap := 0
	for t in owned_tools:
		cap += int(t.capacity_mod)
	return cap


# --- Convenience for the prep/serve flow ---
func can_make_bag(brand_id: StringName, spoons: int) -> bool:
	return consume_sachet(brand_id) and consume_ice(spoons)


func grant_startup_if_empty(start_tools: Array[Tool]) -> void:
	if owned_tools.is_empty():
		grant_startup(start_tools)
