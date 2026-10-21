## Tool.gd
# Data resource for stand equipment/tools. Plan §Data Resources + Implementer Decisions.
class_name Tool
extends Resource

@export var id: StringName = ""
@export var display_name: String = "Tool"
@export var cost: float = 0.0
@export var quality_mod: float = 1.0
@export var capacity_mod: float = 1.0
@export var icon: Texture2D
@export var description: String = ""
