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

## Current virtual-joystick vector, published by VirtualJoystick.gd.
## x = right, y = forward (up). Fed into the Player movement code.
var move_vector: Vector2 = Vector2.ZERO

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
var _locations: Array[LocationDef] = []


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
	_day_end_label = _ui_root.get_node_or_null("DayEnd/Summary") as Label

	var continue_btn := _ui_root.get_node_or_null("DayEnd/Continue") as Button
	if continue_btn != null:
		continue_btn.pressed.connect(func() -> void:
			_day_end_panel.visible = false
			day_end_continue.emit()
		)

	var close_btn := _ui_root.get_node_or_null("TravelPanel/Close") as Button
	if close_btn != null:
		close_btn.pressed.connect(close_location_picker)

	# Connect touch buttons in the UI scene.
	var interact_btn := _ui_root.get_node_or_null("TouchButtons/Interact") as Button
	if interact_btn != null:
		interact_btn.pressed.connect(func() -> void: interact_pressed.emit())

	var travel_btn := _ui_root.get_node_or_null("TouchButtons/Travel") as Button
	if travel_btn != null:
		travel_btn.pressed.connect(func() -> void: open_location_picker())


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


func show_complain(line: String, annoyance: float) -> void:
	if _order_label != null:
		_order_label.text = line
		_order_label.visible = true
	else:
		print("[UILayer] complain: %s" % line)


func clear_callout() -> void:
	if _order_label != null:
		_order_label.visible = false


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
	if _day_end_panel != null:
		_day_end_panel.visible = true
	else:
		print("[UILayer] Akhir hari %d — omset Rp %d, biaya Rp %d, laba Rp %d" % [
			int(recap.get("day", 0)),
			int(recap.get("revenue", 0)),
			int(recap.get("expenses", 0)),
			int(recap.get("profit", 0)),
		])
