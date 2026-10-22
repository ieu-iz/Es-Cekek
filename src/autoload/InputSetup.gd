## InputSetup.gd
# Builds the InputMap programmatically so the same action names exist on desktop
# (keyboard) and Android (onscreen buttons call PrepStation/Customer methods
# directly — see PrepStation input handling and Mobile UI). Registered as an
# autoload in project.godot.
#
# Actions (Task 15 — first-person hands):
#   move_forward, move_back, move_left, move_right  -> jalan
#   interact          -> masuk/keluar meja (mode first-person)
#   travel, ui_accept -> menu
#   swap_hand         -> Q  : tukar isi tangan kiri/kanan
#   turn_body         -> R  : putar badan (bukan pandangan)
#   prep_exit         -> Esc : keluar dari mode prep
#
# Tidak ada lagi tombol pour/water/stir/ice/straw: semua langkah pembuatan
# es dilakukan FISIK dengan mouse (drag objek), lihat `RecipeRules.gd`.
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
	_bind("run", Key.KEY_SHIFT)

	# Task 15 — kontrol first-person.
	_bind("swap_hand", Key.KEY_Q)
	_bind("turn_body", Key.KEY_R)
	_bind("prep_exit", Key.KEY_ESCAPE)


func _bind(action: String, ...keys) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = int(k)
		InputMap.action_add_event(action, ev)
