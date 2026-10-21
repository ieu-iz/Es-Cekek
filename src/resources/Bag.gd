## Bag.gd
# Plan §Bag (runtime) + §Game Systems & Formulas (cost & price bounds).
# Ingredients are consumed when the Bag is built (see PrepStation), NOT when sold.
class_name Bag
extends Resource

@export var portions: Array[SachetPortion] = []
@export var ice_amount: int = 0           # spoon count, 0..MAX_SPOON_ICE
@export var prep_quality: int = 0         # 0..100, correctness x tier x tool
@export var sell_price: float = 0.0       # set by player; must be >= cost
@export var has_straw: bool = false       # ada sedotan? (dipakai visual 3D)

const MAX_SPOON_ICE: int = 8               # Tuning table (Plan)
const ICE_COST_PER_SPOON: float = 0.2     # Tuning table
const FAIR_PROFIT_FLOOR: float = 1.10     # x cost
const FAIR_PROFIT_MAX: float = 2.0        # x cost
const RECOMMENDED_MARKUP: float = 1.35    # hint


func cost() -> float:
	var sachet_cost := 0.0
	for p in portions:
		if p.brand != null:
			sachet_cost += p.volume * p.brand.base_cost
	return sachet_cost + ice_amount * ICE_COST_PER_SPOON


func fair_price_min() -> float:
	return cost() * FAIR_PROFIT_FLOOR


func fair_price_max() -> float:
	return cost() * FAIR_PROFIT_MAX


func recommended_price() -> float:
	return cost() * RECOMMENDED_MARKUP


func has_brand(brand: SachetBrand) -> bool:
	for p in portions:
		if p.brand == brand:
			return true
	return false


func is_empty() -> bool:
	return portions.is_empty()


# Convenience: brand of the (single) poured sachet, or null.
func primary_brand() -> SachetBrand:
	if portions.is_empty():
		return null
	return portions[0].brand
