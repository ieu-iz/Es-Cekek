## SachetBrand.gd
# Data resource for a single es-dikantong sachet (rendengan) brand.
# Plan §Data Resources: name, base_cost, price_tier (1000/2000/5000),
# base_quality (1k->0.35, 2k->0.60, 5k->0.85), sweetness, rarity(0..1), color_tint, icon.
class_name SachetBrand
extends Resource

@export var id: StringName = ""
@export var display_name: String = "Es"
@export var base_cost: float = 0.0
@export_range(1000, 5000, 1000) var price_tier: int = 1000
@export_range(0.0, 1.0) var base_quality: float = 0.35
@export_range(0.0, 1.0) var sweetness: float = 0.5
@export_range(0.0, 1.0) var rarity: float = 0.5
@export var color_tint: Color = Color.WHITE
@export var icon: Texture2D
@export var description: String = ""
