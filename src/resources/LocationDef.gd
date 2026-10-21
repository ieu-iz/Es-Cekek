## LocationDef.gd
# Plan §Data Resources + Tuning table. Distinct rent/foot_traffic/annoyance per location.
class_name LocationDef
extends Resource

@export var id: StringName = ""
@export var display_name: String = "Location"
@export_file("*.tscn") var scene_path: String = ""
@export var rent_cost: float = 20.0
@export_range(0.0, 1.0) var foot_traffic: float = 0.5
@export_range(0.0, 1.0) var annoyance_rate: float = 1.0
@export_range(1, 16, 1) var seats: int = 3
@export_range(1, 32, 1) var max_queue: int = 5
@export var color_palette: Dictionary = {}
@export var description: String = ""
