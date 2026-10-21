## StandEquipment.gd
# Plan §Data Resources: "StandEquipment (node on Stand): holds owned Tools in
# slots; exposes `ice_capacity`, `quality_mod` to PrepStation."
#
# The stand's slots mirror the player's global Inventory.owned_tools, so tools
# bought during the day show up on the stand immediately.
class_name StandEquipment
extends Node

signal equipment_changed

## Tools currently fitted into the stand's slots. Mirrors Inventory.owned_tools.
var tools: Array[Tool] = []


func _ready() -> void:
	refresh_from_inventory()


## Pull the player's owned tools from the global Inventory.
func refresh_from_inventory() -> void:
	tools.clear()
	for t in Inventory.owned_tools:
		tools.append(t)
	equipment_changed.emit()


## The tool currently filling `slot` (or null when the slot is empty).
func tool_in_slot(slot: StringName) -> Tool:
	for t in tools:
		if t.slot == slot:
			return t
	return null


## Spoon capacity of the cooler fitted in the "cooler" slot.
## A bigger cooler REPLACES the small one, so the capacity is read from the
## fitted cooler only (ice_cooler_small => 8, ice_cooler_large => 16).
func ice_capacity() -> int:
	var cooler := tool_in_slot(&"cooler")
	if cooler == null:
		return 0
	return int(cooler.capacity_mod)


## Combined quality multiplier of the fitted tools. The mods MULTIPLY, so the
## startup set (1.0 each) gives exactly 1.0 and every upgrade stacks on top.
func quality_mod() -> float:
	var mod := 1.0
	for t in tools:
		mod *= t.quality_mod
	return mod


func has_tool(tool_id: StringName) -> bool:
	for t in tools:
		if t.id == tool_id:
			return true
	return false


## Fit a tool into its slot, replacing whatever was fitted there before.
## Returns false when the tool is null or already fitted.
func install(tool: Tool) -> bool:
	if tool == null or has_tool(tool.id):
		return false
	var previous := tool_in_slot(tool.slot)
	if previous != null:
		tools.erase(previous)
	tools.append(tool)
	equipment_changed.emit()
	return true


## Ids of the tools currently fitted, in slot order.
func slot_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for t in tools:
		out.append(t.id)
	return out
