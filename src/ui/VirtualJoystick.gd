## VirtualJoystick.gd
# On-screen thumbstick for Android. Plan §Mobile-Specific Concerns.
# Publishes a normalized vector to UILayer.move_vector.
# Convention (sama dengan Input.get_vector): x = +1 ke kanan, y = -1 ke atas
# (maju). Koordinat layar punya y ke bawah, jadi "_value = delta / radius"
# otomatis memberi y negatif saat digerakkan ke atas.
extends Control

## Thumbstick travel radius in pixels.
@export var radius: float = 110.0
## Input below this magnitude is treated as zero.
@export var dead_zone: float = 0.12
## Draw the base ring.
@export var show_base: bool = true

var _touch_index: int = -1
var _center: Vector2 = Vector2.ZERO
var _value: Vector2 = Vector2.ZERO
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1:
				_touch_index = touch.index
				_center = touch.position
				_value = Vector2.ZERO
				_active = true
				_publish()
				queue_redraw()
			accept_event()
		else:
			if touch.index == _touch_index:
				_release()
				accept_event()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update(drag.position)
			accept_event()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_touch_index = -2  # mouse
				_center = mb.position
				_value = Vector2.ZERO
				_active = true
				_publish()
				queue_redraw()
			else:
				_release()
			accept_event()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _touch_index == -2:
			_update(mm.position)
			accept_event()


func _update(position: Vector2) -> void:
	var delta := position - _center
	if delta.length() > radius:
		delta = delta.normalized() * radius
		_center = position - delta
	_value = delta / radius
	if _value.length() < dead_zone:
		_value = Vector2.ZERO
	_publish()
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_active = false
	_value = Vector2.ZERO
	_publish()
	queue_redraw()


func _publish() -> void:
	# Publish via the parent UILayer node instead of the UILayer autoload:
	# the autoload instantiates this scene, so referencing it here is circular.
	var ui := _find_ui_layer()
	if ui == null:
		return
	if ui.has_method("set_move_vector"):
		ui.call("set_move_vector", _value)
	else:
		ui.set("move_vector", _value)


func _find_ui_layer() -> Node:
	# Rantai parent: joystick -> UILayer.tscn root -> CanvasLayer -> autoload UILayer.
	# Autoload-nya yang punya method `set_move_vector`.
	var node := get_parent()
	while node != null:
		if node.has_method("set_move_vector"):
			return node
		node = node.get_parent()
	return null


func _draw() -> void:
	if show_base:
		draw_circle(_center, radius, Color(1, 1, 1, 0.10))
		draw_arc(_center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	if _active:
		draw_circle(_center + _value * radius, 38.0, Color(1, 1, 1, 0.45))
	else:
		draw_circle(_center, 38.0, Color(1, 1, 1, 0.25))
