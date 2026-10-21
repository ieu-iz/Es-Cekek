## InputSetup.gd
# Builds the InputMap programmatically so the same action names exist on desktop
# (keyboard) and Android (onscreen buttons call PrepStation/Customer methods
# directly — see PrepStation input handling and Mobile UI). Registered as an
# autoload in project.godot.
#
# Actions (Plan Task 1 InputMap; shake_* removed — no minigame):
#   move_forward, move_back, move_left, move_right
#   interact, travel, ui_accept
#   pour, add_water, stir, add_ice, add_straw, serve
extends Node

var _configured := false


func _ready() -> void:
	if not _configured:
		_build()
		_configured = true


func _build() -> void:
	_bind("move_forward", Key.W, Key.UP)
	_bind("move_back", Key.S, Key.DOWN)
	_bind("move_left", Key.A, Key.LEFT)
	_bind("move_right", Key.D, Key.RIGHT)
	_bind("interact", Key.E, Key.F)
	_bind("travel", Key.TAB)
	_bind("ui_accept", Key.ENTER, Key.KP_ENTER)

	# Prep pipeline: pour -> water -> stir -> ice -> straw -> serve
	_bind("pour", Key.Q)
	_bind("add_water", Key.R)
	_bind("stir", Key.T)
	_bind("add_ice", Key.G)
	_bind("add_straw", Key.H)
	_bind("serve", Key.F, Key.SPACE)
	_bind("run", Key.SHIFT)


func _bind(action: String, *keys: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = int(k)
		InputMap.action_add_event(action, ev)
