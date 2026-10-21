## Economy.gd
# Singleton. Plan §Economy: day progression, rent per Location, end-of-day recap,
# next-day unlocks. Connected to TimeOfDay.day_ended by the Main bootstrap.
extends Node

signal day_completed(recap: Dictionary)
signal day_started(day: int)

var current_day: int = 1
var day_revenue: float = 0.0
var day_expenses: float = 0.0
var total_profit: float = 0.0
var completed_sales: int = 0
var _brand_revenue: Dictionary = {}    # StringName -> float
var _location_revenue: Dictionary = {}  # StringName -> float


func record_sale(brand_id: StringName, location_id: StringName, revenue: float) -> void:
	day_revenue += revenue
	completed_sales += 1
	_brand_revenue[brand_id] = (_brand_revenue.get(brand_id, 0.0) as float) + revenue
	_location_revenue[location_id] = (_location_revenue.get(location_id, 0.0) as float) + revenue


func add_expense(amount: float) -> void:
	day_expenses += amount


func end_day() -> void:
	# Rent for the stand used today (Implementer decision: rent always counts).
	var loc := LocationManager.current_location
	var rent := 0.0
	if loc != null:
		rent = loc.rent_cost
	add_expense(rent)
	Inventory.remove_money(rent)  # clamps at 0 (failure mode: player $0)

	var best_brand: StringName = ""
	var best_rev := 0.0
	for k in _brand_revenue.keys():
		if _brand_revenue[k] as float > best_rev:
			best_rev = _brand_revenue[k]
			best_brand = k as StringName

	var recap := {
		"day" = current_day,
		"revenue" = day_revenue,
		"expenses" = day_expenses,
		"profit" = day_revenue - day_expenses,
		"best_brand" = best_brand,
		"sales" = completed_sales,
	}
	total_profit += recap["profit"]
	UILayer.show_day_end(recap)
	day_completed.emit(recap)

	# Advance: reset daily tallies, next day, (unlocks handled by Main).
	day_revenue = 0.0
	day_expenses = 0.0
	completed_sales = 0
	_brand_revenue.clear()
	_location_revenue.clear()
	current_day += 1
	day_started.emit(current_day)
