## runtime_test.gd
# Headless runtime smoke test for the vertical slice (Tasks 1-4).
#
# Run with:
#   godot --headless --path . --script res://tests/runtime_test.gd
#
# It boots the real Main scene (autoloads included), then asserts that:
#   1. The Player node exists and is in the "player" group.
#   2. The first location (Pasar) is loaded and is a Location scene.
#   3. The player is teleported to the stand spawn point.
#   4. Traveling to Sekolah and Rumah swaps the location scene.
#   5. The HUD reflects money / day.
#   6. A full day cycle fires (day_ended -> Economy.end_day -> recap).
#
# Exits with code 0 when everything passes, 1 otherwise.

extends SceneTree

const MAIN_SCENE := "res://src/Main.tscn"

var _failures: int = 0
var _checks: int = 0


func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("  [OK]   %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])


func _initialize() -> void:
	# Run the whole thing on the next idle frame so the scene tree is live.
	call_deferred("_run")


func _run() -> void:
	print("=== Es Cekek runtime smoke test ===")

	# --- Boot the real game scene -------------------------------------
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("Gagal memuat %s" % MAIN_SCENE)
		_finish()
		return
	var main := packed.instantiate() as Node3D
	root.add_child(main)
	await process_frame
	await process_frame

	# --- 1. Player ----------------------------------------------------
	var players := get_nodes_in_group("player")
	_check("Player ada di grup 'player'", players.size() == 1, "(dapat %d)" % players.size())
	var player := players[0] as Node3D if players.size() > 0 else null
	_check("Player adalah CharacterBody3D", player is CharacterBody3D)

	# --- 2. First location loaded -------------------------------------
	var loc_mgr := root.get_node_or_null("LocationManager")
	_check("Autoload LocationManager ada", loc_mgr != null)
	var current: LocationDef = null
	if loc_mgr != null:
		current = loc_mgr.get("current_location") as LocationDef
	_check("Lokasi aktif = Pasar", current != null and current.id == &"pasar",
		"(dapat %s)" % (current.id if current != null else "null"))
	_check("Node lokasi ter-mount di WorldRoot", loc_mgr != null and loc_mgr.get("current_root") != null)

	# --- 3. Player positioned at the stand ----------------------------
	var stand_pos := Vector3.ZERO
	var loc_root: Node3D = null
	if loc_mgr != null:
		loc_root = loc_mgr.get("current_root") as Node3D
	if loc_root != null and loc_root.has_method("stand_spawn_position"):
		stand_pos = loc_root.stand_spawn_position()
		if player != null:
			_check("Player berada di stand spawn",
				player.global_position.distance_to(stand_pos) < 0.5,
				"(jarak %.2f)" % player.global_position.distance_to(stand_pos))

	# --- 4. Travel between locations ----------------------------------
	for target in [&"sekolah", &"rumah"]:
		loc_mgr.travel_to(target)
		await process_frame
		await process_frame
		var now: LocationDef = loc_mgr.get("current_location") as LocationDef
		_check("Travel ke %s berhasil" % target, now != null and now.id == target,
			"(dapat %s)" % (now.id if now != null else "null"))
		var mounted: Node3D = loc_mgr.get("current_root") as Node3D
		_check("Scene %s ter-mount" % target, mounted != null)

	# --- 5. Inventory / HUD -------------------------------------------
	var inv := root.get_node_or_null("Inventory")
	_check("Autoload Inventory ada", inv != null)
	if inv != null:
		_check("Saldo awal > 0", inv.get("money") > 0.0, "(uang %.0f)" % inv.get("money"))
		_check("Stok sachet terisi", not (inv.get("sachet_stock") as Dictionary).is_empty())
		_check("Es terisi", inv.get("ice_stock") > 0)
		_check("Startup tools terpasang", (inv.get("owned_tools") as Array).size() == 4,
			"(dapat %d)" % (inv.get("owned_tools") as Array).size())

	var ui := root.get_node_or_null("UILayer")
	_check("Autoload UILayer ada", ui != null)
	if ui != null:
		_check("UILayer memuat scene UI", ui.get("_ui_root") != null)

	# --- 6. Input map --------------------------------------------------
	_check("Aksi 'move_forward' terdaftar", InputMap.has_action("move_forward"))
	_check("Aksi 'interact' terdaftar", InputMap.has_action("interact"))
	_check("Aksi 'travel' terdaftar", InputMap.has_action("travel"))
	_check("Aksi 'run' terdaftar", InputMap.has_action("run"))

	# --- 7. Player movement reacts to input ----------------------------
	if player != null:
		var before: Vector3 = player.global_position
		# Simulate a walk by injecting a movement direction for a few frames.
		player.set_physics_process(true)
		for i in range(30):
			Input.action_press("move_forward")
			await physics_frame
		Input.action_release("move_forward")
		var after: Vector3 = player.global_position
		_check("Player bergerak saat input diberikan",
			before.distance_to(after) > 0.05,
			"(perpindahan %.3f)" % before.distance_to(after))

	# --- 8. Day cycle --------------------------------------------------
	var tod := root.get_node_or_null("TimeOfDay")
	_check("Autoload TimeOfDay ada", tod != null)
	if tod != null:
		tod.end_day_manual()
		await process_frame
		await process_frame
		var econ := root.get_node_or_null("Economy")
		_check("Hari bertambah setelah day end", econ != null and econ.get("current_day") == 2,
			"(hari %s)" % (econ.get("current_day") if econ != null else "?"))

	_finish()


func _fail(msg: String) -> void:
	_failures += 1
	print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("=== Selesai: %d/%d cek lolos, %d gagal ===" % [_checks - _failures, _checks, _failures])
	quit(0 if _failures == 0 else 1)
