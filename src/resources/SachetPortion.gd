## SachetPortion.gd
# Runtime: one poured sachet portion held in a Bag. Plan §Bag (runtime).
class_name SachetPortion
extends Resource

@export var brand: SachetBrand
@export_range(0.0, 1.0) var volume: float = 1.0
