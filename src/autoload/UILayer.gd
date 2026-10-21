## UILayer.gd
# Singleton. Plan §UILayer: money/day HUD, order callout, complain line, price
# setter, loading screen, day-end summary. Mobile anchor + 48dp touch targets.
# Owns the virtual joystick value used by the Player on touch devices.
extends Node

## Emitted when the player taps the on-screen INTERACT button.
signal interact_pressed
## Emitted when the player picks a destination in the travel menu.
signal travel_requested(location_id: StringName)
## Emitted when the player dismisses the day-end summary.
signal day_end_continue
## Emitted when the player taps a button on the prep panel.
## `action` is one of the ACTION_* constants below, `value` is the brand index
## or the step delta depending on the action.
signal prep_action(action: StringName, value: float)
## Emitted when the player taps a button on the shop panel.
## `action` is one of the SHOP_ACTION_* constants below, `value` is the index
## of the tool inside UILayer.shop_tools().
signal shop_action(action: StringName, value: float)

## Prep panel actions.
const ACTION_BRAND_SELECT: StringName = &"brand_select"
const ACTION_VOLUME_INC: StringName = &"volume_inc"
const ACTION_VOLUME_DEC: StringName = &"volume_dec"
const ACTION_ICE_INC: StringName = &"ice_inc"
const ACTION_ICE_DEC: StringName = &"ice_dec"
const ACTION_WATER: StringName = &"add_water"
const ACTION_STIR: StringName = &"stir"
const ACTION_STRAW: StringName = &"add_straw"
const ACTION_BUILD: StringName = &"build"
const ACTION_SERVE: StringName = &"serve"
const ACTION_PRICE_INC: StringName = &"price_inc"
const ACTION_PRICE_DEC: StringName = &"price_dec"
const ACTION_RESTOCK_SACHET: StringName = &"restock_sachet"
const ACTION_RESTOCK_ICE: StringName = &"restock_ice"
const ACTION_CANCEL: StringName = &"cancel"
## Set the price of the offered bag directly (desktop price slider).
const ACTION_PRICE_SET: StringName = &"price_set"

## Shop panel actions.
const SHOP_ACTION_BUY_TOOL: StringName = &"buy_tool"
const SHOP_ACTION_CLOSE: StringName = &"close_shop"

## Price step in rupiah when using the +/- price buttons.
const PRICE_STEP: float = 500.0

## Current virtual-joystick vector, published by VirtualJoystick.gd.
## x = +1 ke kanan, y = -1 ke atas/maju. Konvensi sama dengan
## Input.get_vector("move_left","move_right","move_forward","move_back").
var move_vector: Vector2 = Vector2.ZERO


## Setter untuk virtual joystick.
## VirtualJoystick mencari method ini di rantai parent-nya supaya bisa
## memublikasikan vektor gerak tanpa perlu referensi langsung ke autoload.
func set_move_vector(v: Vector2) -> void:
	move_vector = v

var _ui_root: Control = null
var _order_label: Label = null
var _money_label: Label = null
var _day_label: Label = null
var _loading_label: Label = null
var _error_label: Label = null
var _travel_panel: Control = null
var _travel_list: VBoxContainer = null
var _day_end_panel: Control = null
var _day_end_label: Label = null
var _day_end_detail: Label = null
var _day_bar: ProgressBar = null
var _locations: Array[LocationDef] = []
var _order_queue: VBoxContainer = null
var _order_queue_label: Label = null
var _order_rows_box: VBoxContainer = null
var _order_rows: Array[Label] = []
## Seconds since the order queue was last rebuilt (the list is refreshed at
## most twice a second, not on every frame).
var _order_queue_timer: float = 0.0

# --- Prep panel (Task 6/7) ---
var _prep_panel: PanelContainer = null
var _prep_title: Label = null
var _prep_status: Label = null
var _prep_brand_grid: GridContainer = null
var _prep_brand_buttons: Array[Button] = []
var _volume_label: Label = null
var _ice_label: Label = null
var _price_label: Label = null
var _price_slider: HSlider = null
## True while the slider value is being written BY the UI itself. Without
## this guard the slider -> prep_action -> refresh -> slider loop would never
## end.
var _price_slider_syncing: bool = false
var _build_button: Button = null
var _serve_button: Button = null
var _touch_buttons: Control = null

# --- Shop panel (Task 8) ---
var _shop_panel: PanelContainer = null
var _shop_list: VBoxContainer = null
var _shop_money: Label = null
var _shop_tools: Array[Tool] = []


func _ready() -> void:
	# Create a CanvasLayer so the UI sits above the 3D world.
	var canvas := CanvasLayer.new()
	canvas.name = "UILayerCanvas"
	add_child(canvas)

	var scene_path := "res://src/ui/UILayer.tscn"
	if not ResourceLoader.exists(scene_path):
		push_warning("UILayer: %s tidak ditemukan — memakai fallback print." % scene_path)
		return

	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_warning("UILayer: gagal instantiate %s" % scene_path)
		return

	_ui_root = scene.instantiate() as Control
	if _ui_root == null:
		push_warning("UILayer: root scene harus Control.")
		return
	canvas.add_child(_ui_root)

	_order_label = _ui_root.get_node_or_null("OrderCallout/Message") as Label
	_money_label = _ui_root.get_node_or_null("HUD/Money") as Label
	_day_label = _ui_root.get_node_or_null("HUD/Day") as Label
	_loading_label = _ui_root.get_node_or_null("Overlay/Loading") as Label
	_error_label = _ui_root.get_node_or_null("Overlay/Error") as Label
	_travel_panel = _ui_root.get_node_or_null("TravelPanel") as Control
	_travel_list = _ui_root.get_node_or_null("TravelPanel/List") as VBoxContainer
	_day_end_panel = _ui_root.get_node_or_null("DayEnd") as Control
	_day_end_label = _ui_root.get_node_or_null("DayEnd/Panel/Column/Summary") as Label
	_day_end_detail = _ui_root.get_node_or_null("DayEnd/Panel/Column/Detail") as Label
	_day_bar = _ui_root.get_node_or_null("HUD/DayBar") as ProgressBar

	var continue_btn := _ui_root.get_node_or_null("DayEnd/Panel/Column/Continue") as Button
	if continue_btn != null:
		continue_btn.pressed.connect(func() -> void:
			_day_end_panel.visible = false
			day_end_continue.emit()
		)

	var close_btn := _ui_root.get_node_or_null("TravelPanel/Close") as Button
	if close_btn != null:
		close_btn.pressed.connect(close_location_picker)

	_touch_buttons = _ui_root.get_node_or_null("TouchButtons") as Control

	# Connect touch buttons in the UI scene.
	var interact_btn := _ui_root.get_node_or_null("TouchButtons/Interact") as Button
	if interact_btn != null:
		interact_btn.pressed.connect(func() -> void: interact_pressed.emit())

	var travel_btn := _ui_root.get_node_or_null("TouchButtons/Travel") as Button
	if travel_btn != null:
		travel_btn.pressed.connect(func() -> void: open_location_picker())

	var shop_btn := _ui_root.get_node_or_null("TouchButtons/Shop") as Button
	if shop_btn != null:
		shop_btn.pressed.connect(func() -> void: open_shop())

	_build_prep_panel()
	_build_shop_panel()
	_build_order_queue()

	# The day progress bar follows the clock.
	TimeOfDay.time_tick.connect(_on_time_tick)
	TimeOfDay.day_advanced.connect(func(_day: int) -> void: _on_time_tick(0.0, 0.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("travel"):
		if _travel_panel != null and _travel_panel.visible:
			close_location_picker()
		else:
			open_location_picker()
		get_viewport().set_input_as_handled()

	# Also handle the "interact" action for keyboard (desktop).
	if event.is_action_pressed("interact"):
		interact_pressed.emit()
		get_viewport().set_input_as_handled()


# --- HUD ---------------------------------------------------------------

func update_hud(money: float, day: int, elapsed: float) -> void:
	if _money_label != null:
		_money_label.text = "Rp %s" % _format_rupiah(money)
	if _day_label != null:
		var total := int(elapsed)
		_day_label.text = "Hari %d  ·  %02d:%02d" % [day, (total / 60) % 24, total % 60]
	if _day_bar != null and TimeOfDay.DAY_SECONDS > 0.0:
		_day_bar.value = clampf(elapsed / TimeOfDay.DAY_SECONDS, 0.0, 1.0)


## TimeOfDay.time_tick handler — keeps the day progress bar in sync and
## refreshes the order queue a couple of times per second.
func _on_time_tick(_elapsed: float, normalized: float) -> void:
	if _day_bar != null:
		_day_bar.value = clampf(normalized, 0.0, 1.0)
	# The queue list is rebuilt at most twice a second, not on every frame.
	_order_queue_timer += get_process_delta_time()
	if _order_queue_timer >= 0.5:
		_order_queue_timer = 0.0
		refresh_order_queue()


func _format_rupiah(value: float) -> String:
	var s := str(int(round(value)))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out


# --- Order / complaints -------------------------------------------------

func show_order(brand_display: String) -> void:
	if _order_label != null:
		_order_label.text = "Bang mau es %s!" % brand_display
		_order_label.visible = true
	else:
		print("[UILayer] order: Bang mau es %s!" % brand_display)
	# A new customer usually just spawned — put them in the queue list.
	refresh_order_queue()


func show_complain(line: String, annoyance: float) -> void:
	if _order_label != null:
		_order_label.text = line
		_order_label.visible = true
	else:
		print("[UILayer] complain: %s" % line)


func clear_callout() -> void:
	if _order_label != null:
		_order_label.visible = false


# --- Order queue (Task 9) -----------------------------------------------

## Build the order queue panel: a live list of every customer that is
## currently waiting at the stand, so the player can see the whole queue and
## not just the newest callout.
func _build_order_queue() -> void:
	if _ui_root == null:
		return
	_order_queue = _ui_root.get_node_or_null("OrderQueue") as VBoxContainer
	if _order_queue == null:
		return
	_order_queue_label = _order_queue.get_node_or_null("Title") as Label
	_order_rows_box = _order_queue.get_node_or_null("Rows") as VBoxContainer
	refresh_order_queue()


## Rebuild the queue rows from the customers that are currently waiting.
func refresh_order_queue() -> void:
	if _order_rows_box == null:
		return
	for row in _order_rows:
		if is_instance_valid(row):
			# remove_child() first: queue_free() only schedules the removal for
			# the end of the frame, so the old rows would still be counted (and
			# would pile up on screen on every refresh).
			if row.get_parent() != null:
				row.get_parent().remove_child(row)
			row.queue_free()
	_order_rows.clear()

	var waiting := waiting_customers()
	if _order_queue_label != null:
		_order_queue_label.text = "Antrian: %d orang" % waiting.size()

	for c in waiting:
		var row := Label.new()
		var brand := "?"
		if c.order_brand != null:
			brand = c.order_brand.display_name
		row.text = "%s  ·  kesal %d%%" % [
			brand, int(round(c.annoyance_level * 100.0)),
		]
		row.add_theme_font_size_override("font_size", 18)
		# The row is tinted from calm yellow to angry red.
		row.add_theme_color_override("font_color", _annoyance_color(c.annoyance_level))
		_order_rows_box.add_child(row)
		_order_rows.append(row)


## The customers that are currently waiting for a drink.
func waiting_customers() -> Array[Customer]:
	var out: Array[Customer] = []
	for node in get_tree().get_nodes_in_group("customer"):
		var c := node as Customer
		if c == null or not is_instance_valid(c):
			continue
		if c.state == Customer.State.WAITING or c.state == Customer.State.ARRIVING:
			out.append(c)
	return out


## Queue rows are tinted from calm yellow to angry red.
func _annoyance_color(annoyance: float) -> Color:
	return Color(1.0, 0.9, 0.4).lerp(Color(1.0, 0.35, 0.3), clampf(annoyance, 0.0, 1.0))


# --- Prices -------------------------------------------------------------

func show_price_prompt(cost: float, fair_min: float, fair_max: float) -> float:
	# Task 6 wires the real +/- touch buttons. For now the default price is
	# the recommended markup between the fair bounds.
	return clampf(cost * 1.35, fair_min, fair_max)


# --- Location flow ------------------------------------------------------

func show_loading(visible_: bool, message: String = "") -> void:
	if _loading_label != null:
		_loading_label.text = message
		_loading_label.visible = visible_


func show_error(message: String) -> void:
	if _error_label != null:
		_error_label.text = message
		_error_label.visible = true
		return
	push_warning("UILayer error (no UI root): %s" % message)


func set_locations(locations: Array[LocationDef]) -> void:
	_locations = locations.duplicate()
	_build_travel_buttons()

	# Initially hide the travel panel and day-end panel.
	if _travel_panel != null:
		_travel_panel.visible = false
	if _day_end_panel != null:
		_day_end_panel.visible = false

	# Connect the "travel" action to the UI's travel panel.
	# The signal is already connected in Main.gd.


func open_location_picker() -> void:
	if _travel_panel == null:
		for l in _locations:
			print("[UILayer] lokasi: %s (sewa Rp %d)" % [l.display_name, int(l.rent_cost)])
		return
	_travel_panel.visible = true


func close_location_picker() -> void:
	if _travel_panel != null:
		_travel_panel.visible = false


func _build_travel_buttons() -> void:
	if _travel_list == null:
		return
	for child in _travel_list.get_children():
		child.queue_free()

	for def in _locations:
		var button := Button.new()
		button.text = "%s  ·  sewa Rp %d" % [def.display_name, int(def.rent_cost)]
		button.custom_minimum_size = Vector2(0, 48)
		button.pressed.connect(func() -> void:
			close_location_picker()
			travel_requested.emit(def.id)
		)
		_travel_list.add_child(button)


# --- Prep panel (Task 6/7) ----------------------------------------------

## Build the prep panel. It is created in code so the layout lives in one
## place and every button is guaranteed to be a 48dp touch target.
func _build_prep_panel() -> void:
	if _ui_root == null:
		return

	_prep_panel = PanelContainer.new()
	_prep_panel.name = "PrepPanel"
	_prep_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_prep_panel.offset_left = -384.0
	_prep_panel.offset_right = -8.0
	_prep_panel.offset_top = 96.0
	_prep_panel.offset_bottom = -8.0
	_prep_panel.visible = false
	_prep_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(_prep_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_prep_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_prep_title = Label.new()
	_prep_title.text = "Prep Es"
	_prep_title.add_theme_font_size_override("font_size", 26)
	column.add_child(_prep_title)

	_prep_status = Label.new()
	_prep_status.text = ""
	_prep_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prep_status.add_theme_font_size_override("font_size", 16)
	column.add_child(_prep_status)

	_prep_brand_grid = GridContainer.new()
	_prep_brand_grid.columns = 2
	_prep_brand_grid.add_theme_constant_override("h_separation", 8)
	_prep_brand_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(_prep_brand_grid)

	_volume_label = _add_step_row(column, "Volume", ACTION_VOLUME_DEC, ACTION_VOLUME_INC)
	_ice_label = _add_step_row(column, "Es", ACTION_ICE_DEC, ACTION_ICE_INC)

	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 6)
	column.add_child(steps)
	steps.add_child(_make_button("Air", ACTION_WATER, 0.0))
	steps.add_child(_make_button("Aduk", ACTION_STIR, 0.0))
	steps.add_child(_make_button("Sedotan", ACTION_STRAW, 0.0))

	_price_label = _add_step_row(column, "Harga", ACTION_PRICE_DEC, ACTION_PRICE_INC)

	# Desktop price slider. The plan uses +/- buttons on touch and a slider on
	# desktop, so the slider is hidden on the mobile build.
	_price_slider = HSlider.new()
	_price_slider.min_value = 0.0
	_price_slider.max_value = 100.0
	_price_slider.step = 100.0
	_price_slider.custom_minimum_size = Vector2(0, 48)
	_price_slider.visible = not OS.has_feature("mobile")
	_price_slider.value_changed.connect(_on_price_slider_changed)
	column.add_child(_price_slider)

	var restock := HBoxContainer.new()
	restock.add_theme_constant_override("separation", 6)
	column.add_child(restock)
	restock.add_child(_make_button("Beli Sachet", ACTION_RESTOCK_SACHET, 0.0))
	restock.add_child(_make_button("Beli Es", ACTION_RESTOCK_ICE, 0.0))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	column.add_child(actions)
	actions.add_child(_make_button("Batal", ACTION_CANCEL, 0.0))
	_build_button = _make_button("Selesai", ACTION_BUILD, 0.0)
	actions.add_child(_build_button)
	_serve_button = _make_button("Sajikan", ACTION_SERVE, 0.0)
	actions.add_child(_serve_button)

	refresh_prep_brands()


## One "- <label> +" row. Returns the value label so it can be refreshed.
func _add_step_row(parent: VBoxContainer, label_text: String, dec_action: StringName, inc_action: StringName) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	row.add_child(_make_button("-", dec_action, -1.0))
	var value_label := Label.new()
	value_label.text = "%s: -" % label_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.add_theme_font_size_override("font_size", 18)
	row.add_child(value_label)
	row.add_child(_make_button("+", inc_action, 1.0))
	return value_label


## A 48dp button that emits a prep action when pressed.
func _make_button(text: String, action: StringName, value: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(func() -> void: prep_action.emit(action, value))
	return button


## (Re)build the rack buttons from the catalog brands.
func refresh_prep_brands() -> void:
	if _prep_brand_grid == null:
		return
	for b in _prep_brand_buttons:
		b.queue_free()
	_prep_brand_buttons.clear()

	for i in range(Catalog.brands.size()):
		var brand := Catalog.brands[i]
		var button := Button.new()
		button.text = brand.display_name
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		var index := i
		button.pressed.connect(func() -> void: prep_action.emit(ACTION_BRAND_SELECT, float(index)))
		_prep_brand_grid.add_child(button)
		_prep_brand_buttons.append(button)


## Show / hide the prep panel. The travel/interact buttons are hidden while
## the panel is open so the two control clusters never overlap.
func show_prep_panel(visible_: bool) -> void:
	if _prep_panel != null:
		_prep_panel.visible = visible_
	if _touch_buttons != null:
		_touch_buttons.visible = not visible_


func is_prep_panel_open() -> bool:
	return _prep_panel != null and _prep_panel.visible


## Refresh the panel from a Stand.snapshot() dictionary.
func update_prep(data: Dictionary) -> void:
	if _prep_panel == null:
		return

	var has_bag := bool(data.get("has_bag", false))
	var brand := str(data.get("brand", "-"))
	var volume := float(data.get("volume", 0.0))
	var ice := int(data.get("ice", 0))
	var ice_capacity := int(data.get("ice_capacity", 0))
	var quality := int(data.get("quality", 0))
	var cost := float(data.get("cost", 0.0))
	var stock_sachet := int(data.get("stock_sachet", 0))
	var stock_ice := int(data.get("stock_ice", 0))

	if has_bag:
		_prep_title.text = "Siapkan Sajian"
		_prep_status.text = "%s  ·  kualitas %d%%\nModal Rp %s" % [
			brand, quality, _format_rupiah(cost),
		]
		_price_label.text = "Harga: Rp %s" % _format_rupiah(float(data.get("price", 0.0)))
	else:
		_prep_title.text = "Prep Es"
		_prep_status.text = "%s  ·  modal Rp %s\nStok: %d sachet / %d es" % [
			brand, _format_rupiah(cost), stock_sachet, stock_ice,
		]

	_volume_label.text = "Volume: %d%%" % int(round(volume * 100.0))
	_ice_label.text = "Es: %d/%d" % [ice, ice_capacity]

	_build_button.disabled = has_bag or not bool(data.get("can_build", false))
	_serve_button.disabled = not has_bag

	_update_price_slider(data, has_bag)


## Configure the desktop price slider from the current snapshot. The slider
## range follows the bag's fair bounds, but the real floor is the bag cost
## (a price may never drop below what the ingredients cost).
func _update_price_slider(data: Dictionary, has_bag: bool) -> void:
	if _price_slider == null:
		return
	if not has_bag:
		# No bag on the counter yet, so there is no price to set.
		_price_slider.visible = false
		return
	var cost := float(data.get("cost", 0.0))
	var fair_min := float(data.get("fair_min", cost))
	var fair_max := float(data.get("fair_max", cost))
	var price := float(data.get("price", cost))
	var low := minf(cost, fair_min)
	var high := maxf(fair_max, price)
	if high <= low:
		high = low + 100.0
	# Guard: writing ANY value into the slider must not emit ACTION_PRICE_SET
	# back at the stand. Changing min_value/max_value moves the value as well,
	# and without the guard the slider would silently overwrite the player's
	# price with the cost of the ingredients.
	_price_slider_syncing = true
	_price_slider.visible = not OS.has_feature("mobile")
	_price_slider.min_value = low
	_price_slider.max_value = high
	# A very small step so the slider always shows the EXACT price. With a
	# step of 100 the value is snapped and would no longer match the price
	# that is actually charged.
	_price_slider.step = 0.01
	_price_slider.value = clampf(price, low, high)
	_price_slider_syncing = false


## The player dragged the desktop price slider.
func _on_price_slider_changed(value: float) -> void:
	if _price_slider_syncing:
		return
	prep_action.emit(ACTION_PRICE_SET, value)


# --- Day end ------------------------------------------------------------

func show_day_end(recap: Dictionary) -> void:
	# recap: {day, revenue, expenses, profit, best_brand, sales}
	if _day_end_label != null:
		_day_end_label.text = "Hari %d selesai\n\nOmset   : Rp %s\nBiaya   : Rp %s\nLaba    : Rp %s\nPenjualan: %d cup" % [
			int(recap.get("day", 0)),
			_format_rupiah(float(recap.get("revenue", 0.0))),
			_format_rupiah(float(recap.get("expenses", 0.0))),
			_format_rupiah(float(recap.get("profit", 0.0))),
			int(recap.get("sales", 0)),
		]
	if _day_end_detail != null:
		_day_end_detail.text = _format_day_end_detail(recap)
	if _day_end_panel != null:
		_day_end_panel.visible = true
	else:
		print("[UILayer] Akhir hari %d — omset Rp %d, biaya Rp %d, laba Rp %d" % [
			int(recap.get("day", 0)),
			int(recap.get("revenue", 0)),
			int(recap.get("expenses", 0)),
			int(recap.get("profit", 0)),
		])


## The detailed part of the day-end recap: the profit per location, the rent
## paid per location and the shop tools that just unlocked.
func _format_day_end_detail(recap: Dictionary) -> String:
	var lines: Array[String] = []

	var location_profit: Dictionary = recap.get("location_profit", {})
	if not location_profit.is_empty():
		lines.append("Laba per lokasi:")
		for loc_id in location_profit:
			lines.append("  %s: Rp %s" % [
				_location_display_name(loc_id),
				_format_rupiah(float(location_profit[loc_id])),
			])

	var rents: Dictionary = recap.get("rent_by_location", {})
	if not rents.is_empty():
		var rent_parts: Array[String] = []
		for loc_id in rents:
			rent_parts.append("%s Rp %s" % [
				_location_display_name(loc_id),
				_format_rupiah(float(rents[loc_id])),
			])
		lines.append("Sewa: " + ", ".join(rent_parts))

	var unlocks: Array = recap.get("new_unlocks", [])
	if not unlocks.is_empty():
		var unlock_names: Array[String] = []
		for entry in unlocks:
			var tool := entry as Tool
			if tool != null:
				unlock_names.append(tool.display_name)
		if not unlock_names.is_empty():
			lines.append("Buka di toko: " + ", ".join(unlock_names))

	return "\n".join(lines)


## The display name of a location id (falls back to the raw id).
func _location_display_name(loc_id: Variant) -> String:
	var loc := Catalog.location_by_id(StringName(str(loc_id)))
	if loc != null:
		return loc.display_name
	return str(loc_id)


# --- Shop panel (Task 8) -------------------------------------------------

## Build the shop panel. It is created in code (like the prep panel) so every
## button is a 48dp touch target and the layout lives in one place.
func _build_shop_panel() -> void:
	if _ui_root == null:
		return

	_shop_panel = PanelContainer.new()
	_shop_panel.name = "ShopPanel"
	_shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	_shop_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_shop_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_shop_panel.offset_left = -280.0
	_shop_panel.offset_top = -260.0
	_shop_panel.offset_right = 280.0
	_shop_panel.offset_bottom = 260.0
	_shop_panel.visible = false
	_shop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(_shop_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_shop_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Toko Upgrade"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)

	_shop_money = Label.new()
	_shop_money.text = "Uang: Rp 0"
	_shop_money.add_theme_font_size_override("font_size", 18)
	column.add_child(_shop_money)

	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 8)
	column.add_child(_shop_list)

	var close_btn := Button.new()
	close_btn.text = "Tutup"
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.pressed.connect(close_shop)
	column.add_child(close_btn)

	refresh_shop()


## Rebuild the shop rows from every tool in the catalog. Tools that are still
## locked show their unlock day instead of a price, so the player can plan.
func refresh_shop() -> void:
	if _shop_list == null:
		return
	for child in _shop_list.get_children():
		child.queue_free()
	_shop_tools.clear()

	if _shop_money != null:
		_shop_money.text = "Uang: Rp %s" % _format_rupiah(Inventory.money)

	var day := _current_day()
	for tool in Catalog.all_tools():
		_shop_tools.append(tool)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_shop_list.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var name_label := Label.new()
		name_label.text = tool.display_name
		name_label.add_theme_font_size_override("font_size", 18)
		info.add_child(name_label)

		var desc := Label.new()
		desc.text = tool.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 14)
		info.add_child(desc)

		var index := _shop_tools.size() - 1
		var owned := Inventory.has_tool(tool.id)
		var locked := tool.unlock_day > day
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 48)
		button.add_theme_font_size_override("font_size", 16)
		if owned:
			button.text = "Terpasang"
			button.disabled = true
		elif locked:
			# Not unlocked yet — show when it becomes available.
			button.text = "Terkunci\nHari %d" % tool.unlock_day
			button.disabled = true
		elif tool.cost <= 0.0:
			# Startup gear is not for sale — it is the player's initial capital.
			button.text = "Modal awal"
			button.disabled = true
		else:
			button.text = "Beli\nRp %s" % _format_rupiah(tool.cost)
			button.disabled = not Inventory.can_afford(tool.cost)
			# Deferred: buying rebuilds the shop rows, so the button that is
			# currently emitting must not be freed mid-signal.
			button.pressed.connect(func() -> void:
				call_deferred("_emit_shop_buy", index)
			)
		row.add_child(button)


## Open the shop panel and refresh its contents.
func open_shop() -> void:
	if _shop_panel == null:
		return
	refresh_shop()
	_shop_panel.visible = true
	if _touch_buttons != null:
		_touch_buttons.visible = false


## Close the shop panel.
func close_shop() -> void:
	if _shop_panel != null:
		_shop_panel.visible = false
	if _touch_buttons != null and not is_prep_panel_open():
		_touch_buttons.visible = true


func is_shop_panel_open() -> bool:
	return _shop_panel != null and _shop_panel.visible


## The day the shop is currently offering its stock for. Economy is autoloaded
## AFTER UILayer, so it is fetched from the tree instead of referenced
## directly (it may not exist yet while UILayer is booting).
func _current_day() -> int:
	var econ := get_tree().root.get_node_or_null("Economy")
	if econ != null:
		return int(econ.get("current_day"))
	return 1


## Emit the buy request for the tool at `index` in the shop list.
func _emit_shop_buy(index: int) -> void:
	shop_action.emit(SHOP_ACTION_BUY_TOOL, float(index))


## Buy the tool at `index` inside the shop list. Returns true on success.
func buy_tool_at(index: int) -> bool:
	if index < 0 or index >= _shop_tools.size():
		return false
	var tool := _shop_tools[index]
	var ok := Inventory.buy_tool(tool)
	if ok:
		show_order("Beli %s" % tool.display_name)
	else:
		show_error("Gagal beli %s" % tool.display_name)
	refresh_shop()
	return ok
