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
	_bind("move_forward", Key.KEY_W, Key.KEY_UP)
	_bind("move_back", Key.KEY_S, Key.KEY_DOWN)
	_bind("move_left", Key.KEY_A, Key.KEY_LEFT)
	_bind("move_right", Key.KEY_D, Key.KEY_RIGHT)
	_bind("interact", Key.KEY_E, Key.KEY_F)
	_bind("travel", Key.KEY_TAB)
	_bind("ui_accept", Key.KEY_ENTER, Key.KEY_KP_ENTER)

	# Prep pipeline: pour -> water -> stir -> ice -> straw -> serve
	_bind("pour", Key.KEY_Q)
	_bind("add_water", Key.KEY_R)
	_bind("stir", Key.KEY_T)
	_bind("add_ice", Key.KEY_G)
	_bind("add_straw", Key.KEY_H)
	_bind("serve", Key.KEY_F, Key.KEY_SPACE)
	_bind("run", Key.KEY_SHIFT)


func _bind(action: String, ...keys) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = int(k)
		InputMap.action_add_event(action, ev)
