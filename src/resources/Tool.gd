## Tool.gd
# Data resource for stand equipment/tools. Plan §Data Resources + Implementer Decisions.
#
# A tool belongs to an equipment SLOT. Installing a tool into an occupied slot
# replaces the previous one, so the player upgrades instead of stacking a
# second cooler on top of the first. `quality_mod` values multiply together
# (the startup set is 1.0 each, so the startup quality_mod is exactly 1.0).
class_name Tool
extends Resource

## Equipment slot this tool occupies. One tool per slot.
## Known slots: "table", "hook", "water", "cooler", "mixer".
@export var slot: StringName = &"misc"
@export var id: StringName = ""
@export var display_name: String = "Tool"
@export var cost: float = 0.0
## Multiplier on the prep quality. 1.0 = no effect. Upgrades raise it.
@export var quality_mod: float = 1.0
## Spoon capacity contribution (ice_cooler_small => 8; non-coolers => 0).
@export var capacity_mod: float = 1.0
## Earliest day on which this tool can be bought in the shop.
@export var unlock_day: int = 1
## True for tools bought in the shop (the startup set is granted for free).
@export var is_upgrade: bool = false
@export var icon: Texture2D
@export var description: String = ""
