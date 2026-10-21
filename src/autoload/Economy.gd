## Economy.gd
# Singleton. Plan §Economy: day progression, rent per Location, end-of-day recap,
# next-day unlocks. Connected to TimeOfDay.day_ended by the Main bootstrap.
#
# Rent rule (Task 8): the player pays the rent of every location where they
# actually did business that day, plus the location they are standing in when
# the day closes (a day with no sales still costs rent — the stand was set up).
extends Node

signal day_completed(recap: Dictionary)
signal day_started(day: int)

var current_day: int = 1
var day_revenue: float = 0.0
var day_expenses: float = 0.0
var total_profit: float = 0.0
var completed_sales: int = 0
## The recap of the most recently finished day. Kept around because the daily
## tallies are reset as soon as the day ends.
var last_recap: Dictionary = {}
## Locations where the player served customers today (rent is charged per
## location, only once per day).
var _traded_locations: Dictionary = {}  # StringName -> bool
## Rent paid today, per location. StringName -> float.
var _rent_by_location: Dictionary = {}
var _brand_revenue: Dictionary = {}    # StringName -> float
var _location_revenue: Dictionary = {}  # StringName -> float


func record_sale(brand_id: StringName, location_id: StringName, revenue: float) -> void:
	day_revenue += revenue
	completed_sales += 1
	_brand_revenue[brand_id] = (_brand_revenue.get(brand_id, 0.0) as float) + revenue
	_location_revenue[location_id] = (_location_revenue.get(location_id, 0.0) as float) + revenue
	if location_id != &"":
		_traded_locations[location_id] = true


func add_expense(amount: float) -> void:
	day_expenses += amount


## Charge the rent of `location_id` (once per day) and take it from the money.
## Returns the rent that was charged (0 when the location is unknown or the
## rent was already paid today).
func charge_rent(location_id: StringName) -> float:
	if location_id == &"":
		return 0.0
	if _rent_by_location.has(location_id):
		return 0.0
	var loc := Catalog.location_by_id(location_id)
	if loc == null:
		return 0.0
	var rent := loc.rent_cost
	_rent_by_location[location_id] = rent
	add_expense(rent)
	Inventory.remove_money(rent)  # clamps at 0 (failure mode: player $0)
	return rent


## The rent that was charged today, per location.
func rent_by_location() -> Dictionary:
	return _rent_by_location.duplicate()


func end_day() -> void:
	# Rent for every location the player traded at today, plus the location the
	# stand was left in when the day closed.
	var charged: Array[StringName] = []
	for id in _traded_locations.keys():
		if charge_rent(id as StringName) > 0.0:
			charged.append(id as StringName)
	if charged.is_empty():
		var loc := LocationManager.current_location
		if loc != null:
			if charge_rent(loc.id) > 0.0:
				charged.append(loc.id)

	var best_brand: StringName = ""
	var best_rev := 0.0
	for k in _brand_revenue.keys():
		if _brand_revenue[k] as float > best_rev:
			best_rev = _brand_revenue[k]
			best_brand = k as StringName

	# Per-location profit (revenue minus the rent of that location).
	var location_profit: Dictionary = {}
	for id in _location_revenue.keys():
		var rev := _location_revenue[id] as float
		var rent := _rent_by_location.get(id, 0.0) as float
		location_profit[id] = rev - rent

	var recap := {
		"day" = current_day,
		"revenue" = day_revenue,
		"expenses" = day_expenses,
		"profit" = day_revenue - day_expenses,
		"best_brand" = best_brand,
		"sales" = completed_sales,
		"location_revenue" = _location_revenue.duplicate(),
		"brand_revenue" = _brand_revenue.duplicate(),
		"location_profit" = location_profit,
		"rent_by_location" = _rent_by_location.duplicate(),
		"locations_used" = charged,
		"new_unlocks" = new_unlocks_for_day(current_day + 1),
	}
	total_profit += recap["profit"]
	last_recap = recap
	UILayer.show_day_end(recap)
	day_completed.emit(recap)

	# Advance: reset daily tallies, next day, (unlocks handled by Main).
	day_revenue = 0.0
	day_expenses = 0.0
	completed_sales = 0
	_brand_revenue.clear()
	_location_revenue.clear()
	_traded_locations.clear()
	_rent_by_location.clear()
	current_day += 1
	day_started.emit(current_day)


## The shop tools that become available on `day` but were not available on the
## day before — this is what the day-end summary reports as "new unlocks".
func new_unlocks_for_day(day: int) -> Array:
	var previous: Array = Catalog.available_on_day(day - 1)
	var out: Array = []
	for t in Catalog.available_on_day(day):
		var found := false
		for p in previous:
			if (p as Tool).id == t.id:
				found = true
				break
		if not found:
			out.append(t)
	return out
