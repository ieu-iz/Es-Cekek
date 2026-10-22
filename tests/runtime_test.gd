## runtime_test.gd
# Headless runtime smoke test for the whole MVP loop (Tasks 1-7).
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
#   7. Task 5: Catalog / StandEquipment / Inventory consume-on-build.
#   8. Task 6: the prep pipeline produces a Bag with the right prep_quality.
#   9. Task 7: customers spawn, complain, and are served / refused.
#
# Exits with code 0 when everything passes, 1 otherwise.

extends Node

const MAIN_SCENE := "res://src/Main.tscn"
## Dimuat lewat path (bukan `class_name`) supaya test tidak bergantung pada
## global class cache yang bisa saja basi di folder .godot.
const PLAYER_SCRIPT := preload("res://src/entities/Player.gd")
const PREP_OBJECT_SCRIPT := preload("res://src/prep/PrepObject.gd")
const HAND_SCRIPT := preload("res://src/prep/Hand.gd")
const PREP_CONTROLLER_SCRIPT := preload("res://src/prep/PrepController.gd")
const RECIPE_RULES_SCRIPT := preload("res://src/prep/RecipeRules.gd")

var _failures: int = 0
var _checks: int = 0
## Baris komplain pelanggan yang tertangkap selama tes Task 15.
var _complain_lines: Array[String] = []


func _check(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("  [OK]   %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
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
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- 1. Player ----------------------------------------------------
	var players := get_tree().get_nodes_in_group("player")
	_check("Player ada di grup 'player'", players.size() == 1, "(dapat %d)" % players.size())
	var player: Node3D = players[0] if players.size() > 0 else null
	_check("Player adalah CharacterBody3D", player is CharacterBody3D)

	# --- 2. First location loaded -------------------------------------
	var loc_mgr := get_tree().root.get_node_or_null("LocationManager")
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
		await get_tree().process_frame
		await get_tree().process_frame
		var now: LocationDef = loc_mgr.get("current_location") as LocationDef
		_check("Travel ke %s berhasil" % target, now != null and now.id == target,
			"(dapat %s)" % (now.id if now != null else "null"))
		var mounted: Node3D = loc_mgr.get("current_root") as Node3D
		_check("Scene %s ter-mount" % target, mounted != null)
		loc_root = mounted

	# --- 5. Inventory / HUD -------------------------------------------
	var inv := get_tree().root.get_node_or_null("Inventory")
	_check("Autoload Inventory ada", inv != null)
	if inv != null:
		_check("Saldo awal > 0", inv.get("money") > 0.0, "(uang %.0f)" % inv.get("money"))
		_check("Inventory itu node autoload", inv.name == "Inventory")
		_check("Stok sachet terisi", not (inv.get("sachet_stock") as Dictionary).is_empty())
		_check("Es terisi", inv.get("ice_stock") > 0)
		_check("Startup tools terpasang", (inv.get("owned_tools") as Array).size() == 4,
			"(dapat %d)" % (inv.get("owned_tools") as Array).size())
		_check("Upgrade toko TIDAK diberikan gratis",
			not (inv.get("owned_tools") as Array).any(func(t): return (t as Tool).id == &"ice_cooler_large"),
			"(harus dibeli di toko)")

	var ui := get_tree().root.get_node_or_null("UILayer")
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
		player.set_physics_process(true)
		# Simulate a walk by injecting a movement direction for a few frames.
		for i in range(30):
			Input.action_press("move_forward")
			await get_tree().physics_frame
		Input.action_release("move_forward")
		var after: Vector3 = player.global_position
		_check("Player bergerak saat input diberikan",
			before.distance_to(after) > 0.05,
			"(perpindahan %.3f)" % before.distance_to(after))

	# --- 8. Task 5: catalog, stand equipment, consume-on-build --------
	await _test_task5(loc_root)

	# --- 9. Task 6: the prep pipeline ---------------------------------
	await _test_task6(loc_root)

	# --- 10. Task 7: customers, annoyance, serve / refuse --------------
	await _test_task7(loc_root)

	# --- 11. Task 8: tool slots, shop, per-location rent ---------------
	await _test_task8(loc_root)

	# --- 12. Task 9: UILayer polish (order queue, price slider, recap) -
	await _test_task9(loc_root)

	# --- 13. Task 15: first-person hands (RecipeRules + PrepStation + PrepHUD) -
	await _test_task15(loc_root)

	# --- 13b. Task 16: kontrol layar sentuh (multi-jari + tombol layar) ----
	await _test_task16(loc_root)

	# --- 13. Task 4: TimeOfDay drives the real day/night lighting ------
	await _test_timeofday_lighting()

	# --- 14. Task 12: 3D feedback (bag mesh, bubble, annoyance pose) ---
	await _test_task12_feedback(loc_root)

	# --- 15. Task 12: procedural SFX autoload ----------------------------
	await _test_task12_sfx(loc_root)

	# --- 16. Task 11: virtual joystick publishes movement --------------
	await _test_virtual_joystick()

	# --- 17. Arah gerak: W harus maju, S mundur (regresi build .exe) ----
	await _test_movement_direction()

	# --- 17. Day cycle -------------------------------------------------
	var tod := get_tree().root.get_node_or_null("TimeOfDay")
	_check("Autoload TimeOfDay ada", tod != null)
	if tod != null:
		tod.end_day_manual()
		await get_tree().process_frame
		await get_tree().process_frame
		var econ := get_tree().root.get_node_or_null("Economy")
		_check("Hari bertambah setelah day end", econ != null and econ.get("current_day") == 2,
			"(hari %s)" % (econ.get("current_day") if econ != null else "?"))
		# The daily tallies are reset when the day ends, so the recap is the
		# authoritative record of what happened.
		var recap: Dictionary = econ.get("last_recap") if econ != null else {}
		_check("Penjualan tercatat di rekap", int(recap.get("sales", 0)) >= 1,
			"(penjualan %s)" % str(recap.get("sales", 0)))
		_check("Rekap punya omzet", float(recap.get("revenue", 0.0)) > 0.0,
			"(omzet %s)" % str(recap.get("revenue", 0.0)))
		_check("Rekap punya brand terbaik", str(recap.get("best_brand", "")) != "",
			"(brand %s)" % str(recap.get("best_brand", "")))

	_finish()


# --- Task 5 -------------------------------------------------------------

func _test_task5(loc_root: Node3D) -> void:
	# NOTE: in --script mode the autoload *values* (Catalog, Inventory, ...) are
	# not registered as global identifiers at compile time, so we fetch them as
	# typed nodes from the scene tree root instead.
	var catalog: Catalog = get_tree().root.get_node_or_null("Catalog")
	_check("Autoload Catalog ada", catalog != null)
	if catalog == null:
		return
	_check("Catalog punya 3 lokasi", (catalog.get("locations") as Array).size() == 3)
	_check("Catalog punya 4 brand", (catalog.get("brands") as Array).size() == 4)
	_check("Catalog punya 6 tool (4 startup + 2 toko)", (catalog.get("tools") as Array).size() == 6)
	_check("Catalog punya 4 startup tool", catalog.startup_tools().size() == 4,
		"(dapat %d)" % catalog.startup_tools().size())
	_check("Catalog punya 2 tool toko", catalog.shop_tools().size() == 2,
		"(dapat %d)" % catalog.shop_tools().size())

	var stand := _find_stand(loc_root)
	_check("Stand ter-mount di lokasi", stand != null)
	if stand == null:
		return

	var equip := stand.equipment
	_check("StandEquipment punya 4 tool", equip.tools.size() == 4,
		"(dapat %d)" % equip.tools.size())
	_check("Kapasitas es = 8 sendok", equip.ice_capacity() == 8,
		"(dapat %d)" % equip.ice_capacity())
	_check("Quality mod = 1.0", is_equal_approx(equip.quality_mod(), 1.0),
		"(dapat %.2f)" % equip.quality_mod())
	_check("StandEquipment punya slot cooler kecil",
		equip.tool_in_slot(&"cooler") != null
		and equip.tool_in_slot(&"cooler").id == &"ice_cooler_small")
	_check("StandEquipment punya ice_cooler_small", equip.has_tool(&"ice_cooler_small"))
	_check("Rack prep punya 4 brand", stand.prep_station.rack.size() == 4,
		"(dapat %d)" % stand.prep_station.rack.size())

	# REGRESI: node CounterShape pernah ditulis tanpa atribut `type=`, jadi
	# Godot menjadikannya StaticBody3D (tipe warisan dari parent) dan
	# assignment `shape` gagal diam-diam. Akibatnya Counter tidak punya
	# collision shape sama sekali, sehingga InteractArea pemain tidak pernah
	# mendeteksi stand -> panel prep tidak bisa dibuka saat main.
	var counter := stand.get_node_or_null("Counter") as StaticBody3D
	_check("Counter adalah StaticBody3D", counter != null)
	var counter_shape: CollisionShape3D = null
	if counter != null:
		for child in counter.get_children():
			if child is CollisionShape3D:
				counter_shape = child as CollisionShape3D
				break
	_check("Counter punya collision shape yang valid",
		counter_shape != null and counter_shape.shape != null)

	# Marker kursi + antrean menentukan batas spawn (Implementer Decision #3).
	_check("Stand punya 3 kursi", stand.seat_positions().size() == 3,
		"(dapat %d)" % stand.seat_positions().size())
	_check("Stand punya 5 slot antrean", stand.queue_positions().size() == 5,
		"(dapat %d)" % stand.queue_positions().size())

	# Propsi stand harus mesh Kenney sungguhan, bukan box primitif dulu.
	_check("Meja stand memakai mesh Kenney",
		_has_mesh(stand.get_node_or_null("Counter/CounterMesh")))
	_check("Kursi stand memakai mesh Kenney",
		_has_mesh(stand.get_node_or_null("Seats/Chair_1")))
	_check("Prodi prep memakai mesh Kenney",
		_has_mesh(stand.get_node_or_null("PrepStation/IceCooler")))

	# Consume-on-build must be atomic: probing never eats stock.
	var inv: Inventory = get_tree().root.get_node_or_null("Inventory")
	var tejus: SachetBrand = catalog.brand_by_id(&"tejus")
	_check("Catalog menemukan brand tejus", tejus != null)
	if tejus == null or inv == null:
		return

	var sachets_before: int = inv.sachet_stock.get(tejus.id, 0) as int
	var ice_before: int = inv.ice_stock
	_check("can_make_bag tidak mengonsumsi stok",
		inv.can_make_bag(tejus.id, 2)
		and (inv.sachet_stock.get(tejus.id, 0) as int) == sachets_before
		and inv.ice_stock == ice_before)

	# A failed build (not enough ice) must not eat the sachet.
	inv.ice_stock = 0
	var ok: bool = inv.try_consume(tejus.id, 2)
	_check("try_consume gagal saat es habis", not ok)
	_check("Sachet tidak terpakai saat gagal",
		(inv.sachet_stock.get(tejus.id, 0) as int) == sachets_before,
		"(dapat %d, harusnya %d)" % [(inv.sachet_stock.get(tejus.id, 0) as int), sachets_before])
	inv.ice_stock = ice_before

	# Restock with money.
	var money_before: float = inv.money
	var bought: int = inv.restock_sachets(tejus, 3)
	_check("Restock sachet menambah stok", bought == 3
		and (inv.sachet_stock.get(tejus.id, 0) as int) == sachets_before + 3,
		"(dapat %d)" % bought)
	_check("Restock mengurangi uang", inv.money < money_before)


# --- Task 6 -------------------------------------------------------------

func _test_task6(loc_root: Node3D) -> void:
	var stand := _find_stand(loc_root)
	if stand == null:
		_fail("Stand tidak ada — Task 6 dilewati.")
		return
	var prep := stand.prep_station
	var catalog: Catalog = get_tree().root.get_node_or_null("Catalog")
	if catalog == null:
		return

	var low_brand: SachetBrand = catalog.brand_by_id(&"tejus")
	var high_brand: SachetBrand = catalog.brand_by_id(&"frenta")
	if low_brand == null or high_brand == null:
		_fail("Brand tidak ditemukan — Task 6 dilewati.")
		return

	var inv: Inventory = get_tree().root.get_node_or_null("Inventory")

	# --- Perfect bag of the cheap tier ---
	prep.open_build()
	prep.select_brand(low_brand)
	prep.pour(1.0)
	prep.add_water()
	prep.stir()
	prep.add_ice(4)
	prep.add_straw()
	_check("step_score = 1.0 untuk langkah sempurna", is_equal_approx(prep.step_score(), 1.0),
		"(dapat %.2f)" % prep.step_score())

	var sachets_before: int = inv.sachet_stock.get(low_brand.id, 0) as int
	var ice_before: int = inv.ice_stock
	var bag := prep.build_bag()
	_check("Bag berhasil dibuat", bag != null)
	if bag == null:
		return
	_check("prep_quality tier 1k = 35", bag.prep_quality == 35, "(dapat %d)" % bag.prep_quality)
	_check("Sachet dikonsumsi saat build",
		(inv.sachet_stock.get(low_brand.id, 0) as int) == sachets_before - 1,
		"(dapat %d)" % (inv.sachet_stock.get(low_brand.id, 0) as int))
	_check("Es dikonsumsi saat build", inv.ice_stock == ice_before - 4,
		"(dapat %d)" % inv.ice_stock)
	_check("Volume saclet 1.0", bag.portions[0].volume == 1.0)
	_check("Brand di bag benar", bag.primary_brand() == low_brand)
	_check("Harga awal = recommended", is_equal_approx(bag.sell_price, bag.recommended_price()))
	_check("Cost = volume x base_cost + es", is_equal_approx(bag.cost(),
		low_brand.base_cost + 4 * Bag.ICE_COST_PER_SPOON),
		"(dapat %.2f)" % bag.cost())

	# --- Perfect bag of the premium tier: visibly richer ---
	prep.open_build()
	prep.select_brand(high_brand)
	prep.pour(1.0)
	prep.add_water()
	prep.stir()
	prep.add_ice(4)
	prep.add_straw()
	var bag2 := prep.build_bag()
	_check("prep_quality tier 5k = 85", bag2 != null and bag2.prep_quality == 85,
		"(dapat %d)" % (bag2.prep_quality if bag2 != null else -1))
	_check("Tier 5k lebih tinggi dari 1k",
		bag2 != null and bag2.prep_quality > bag.prep_quality)

	# --- A sloppy bag scores much lower ---
	prep.open_build()
	prep.select_brand(high_brand)
	prep.pour(0.3)
	prep.add_ice(1)
	var bag3 := prep.build_bag()
	_check("Proses asal-asalan punya kualitas rendah",
		bag3 != null and bag3.prep_quality < 20,
		"(dapat %d)" % (bag3.prep_quality if bag3 != null else -1))
	_check("Volume < 0.5 menurunkan step_score", prep.step_score() < 0.5,
		"(dapat %.2f)" % prep.step_score())

	# --- Ice is capped by the stand's ice capacity ---
	prep.open_build()
	prep.select_brand(low_brand)
	prep.add_ice(99)
	_check("Es dibatasi kapasitas cooler (8)", prep.ice_amount == 8,
		"(dapat %d)" % prep.ice_amount)

	# --- Task 15: PrepHUD minimal (panel prep lama sudah dibongkar) ---
	stand.current_bag = null
	stand.interact_at_stand()
	var ui_layer := get_tree().root.get_node_or_null("UILayer") as UILayer
	_check("PrepHUD ada di UI root", ui_layer != null and ui_layer.get("_prep_panel") != null)
	_check("PrepHUD terbuka saat interact", ui_layer != null and ui_layer.is_prep_panel_open())
	var serve_btn := ui_layer.get("_serve_button") as Button if ui_layer != null else null
	var exit_btn := ui_layer.get("_exit_button") as Button if ui_layer != null else null
	_check("Tombol 'Serahkan' ada dan 48dp",
		serve_btn != null and serve_btn.custom_minimum_size.y >= 48.0)
	_check("Tombol 'Keluar' ada dan 48dp",
		exit_btn != null and exit_btn.custom_minimum_size.y >= 48.0)
	stand.close_prep()
	_check("PrepHUD tertutup setelah keluar", ui_layer != null and not ui_layer.is_prep_panel_open())


# --- Task 15: first-person hands ----------------------------------------

## Handler sinyal `Customer.complain` khusus tes Task 15.
func _on_test_complain(line: String, _annoyance: float) -> void:
	_complain_lines.append(line)


## Pegang `obj` dengan `hand`. Isi tangan sebelumnya dikembalikan ke meja.
func _hand_hold(hand: Hand, obj: PrepObject) -> void:
	if hand == null or obj == null:
		return
	if hand.holds == obj:
		return
	if hand.holds != null:
		var old := hand.holds
		hand.release_at(_home_world(old))
	hand.grab(obj)


## Posisi meja asal sebuah objek (koordinat dunia).
func _home_world(obj: PrepObject) -> Vector3:
	if obj == null:
		return Vector3.ZERO
	if obj.home_parent != null and is_instance_valid(obj.home_parent):
		return obj.home_parent.to_global(obj.home_transform.origin)
	return obj.global_position


## Kosongkan state semua objek prep (dipakai sebelum masak ulang).
func _reset_prep_objects(objs: Dictionary) -> void:
	for key in objs.keys():
		var o := objs[key] as PrepObject
		if o != null:
			o.reset_contents()


## Satu langkah resep: `actor` di tangan kiri, `target` di tangan kanan.
## Mengembalikan nama langkah yang terpicu (StringName kosong kalau tidak ada).
func _prep_step(session: PrepStation, lh: Hand, rh: Hand, actor: PrepObject, target: PrepObject) -> StringName:
	if session == null or lh == null or rh == null or actor == null or target == null:
		return &""
	# Kedua tangan dikosongkan dulu: kalau tidak, objek yang dipegang tangan
	# lain tidak bisa diambil (Hand.grab menolak objek yang sudah dipegang).
	if lh.holds != null:
		lh.release_at(_home_world(lh.holds))
	if rh.holds != null:
		rh.release_at(_home_world(rh.holds))
	_hand_hold(lh, actor)
	_hand_hold(rh, target)
	# Dua objek harus berdekatan supaya rules mendeteksinya.
	actor.global_position = target.global_position
	var res := RecipeRules.evaluate(lh, rh)
	if res.is_empty():
		return &""
	RecipeRules.apply_step(session, res)
	return StringName(res.get("step", &""))


## Masak satu es penuh secara fisik (7 pemicu rules).
func _cook_physical(session: PrepStation, lh: Hand, rh: Hand, objs: Dictionary) -> Array[StringName]:
	var steps: Array[StringName] = []
	steps.append(_prep_step(session, lh, rh, objs.get("Scissors"), objs.get("Sachet_1")))
	steps.append(_prep_step(session, lh, rh, objs.get("Sachet_1"), objs.get("PlasticBag")))
	steps.append(_prep_step(session, lh, rh, objs.get("WaterJug"), objs.get("PlasticBag")))
	steps.append(_prep_step(session, lh, rh, objs.get("Spoon"), objs.get("PlasticBag")))
	steps.append(_prep_step(session, lh, rh, objs.get("IceScoop"), objs.get("IceCooler")))
	steps.append(_prep_step(session, lh, rh, objs.get("IceScoop"), objs.get("PlasticBag")))
	steps.append(_prep_step(session, lh, rh, objs.get("Straw"), objs.get("PlasticBag")))
	return steps


## Jumlah objek prep dengan jenis tertentu di bawah `node`.
func _count_prep_kind(node: Node, kind: int) -> int:
	var total := 0
	for child in node.get_children():
		var obj := child as PrepObject
		if obj != null and int(obj.kind) == kind:
			total += 1
	return total


func _test_task15(loc_root: Node3D) -> void:
	var stand := _find_stand(loc_root)
	if stand == null:
		_fail("Stand tidak ada — Task 15 dilewati.")
		return
	var prep := stand.prep_station
	var catalog: Catalog = get_tree().root.get_node_or_null("Catalog")
	var inv: Inventory = get_tree().root.get_node_or_null("Inventory")
	_check("PrepStation punya sesi resep", prep != null)
	if prep == null or catalog == null or inv == null:
		return

	# --- A. Objek fisik di meja ------------------------------------------
	var kinds: Dictionary = {
		"Sachet_1": PrepObject.Kind.SACHET,
		"Scissors": PrepObject.Kind.SCISSORS,
		"PlasticBag": PrepObject.Kind.PLASTIC_BAG,
		"WaterJug": PrepObject.Kind.WATER_JUG,
		"IceCooler": PrepObject.Kind.ICE_COOLER,
		"IceScoop": PrepObject.Kind.ICE_SCOOP,
		"Spoon": PrepObject.Kind.SPOON,
		"Straw": PrepObject.Kind.STRAW,
	}
	var objs: Dictionary = {}
	for key in kinds.keys():
		var obj := prep.get_node_or_null(NodePath(key)) as PrepObject
		_check("Objek '%s' ada di meja" % key, obj != null)
		if obj == null:
			continue
		_check("Objek '%s' jenisnya benar" % key, int(obj.kind) == int(kinds[key]))
		objs[key] = obj
	_check("Rak berisi 4 sachet", _count_prep_kind(prep, PrepObject.Kind.SACHET) == 4)

	# --- B. Rig first-person di Player -----------------------------------
	var players := get_tree().get_nodes_in_group("player")
	var player: Player = null
	if players.size() > 0:
		player = players[0] as Player
	_check("Player ada di group 'player'", player != null)
	if player == null:
		return
	var rig := player.get_node_or_null("PrepRig") as Node3D
	var lh := player.get_node_or_null("PrepRig/LeftHand") as Hand
	var rh := player.get_node_or_null("PrepRig/RightHand") as Hand
	var ctrl := player.get_node_or_null("PrepController") as PrepController
	_check("PrepRig first-person ada", rig != null)
	_check("Tangan kiri & kanan ada", lh != null and rh != null)
	_check("PrepController ada di Player", ctrl != null)
	_check("Tangan kiri ditandai kiri", lh != null and lh.side == Hand.HandSide.LEFT)
	_check("Tangan kanan ditandai kanan", rh != null and rh.side == Hand.HandSide.RIGHT)
	if lh == null or rh == null or ctrl == null:
		return

	# --- C. Aturan tangan terdekat ---------------------------------------
	var probe := objs.get("Sachet_1") as PrepObject
	if probe != null:
		lh.global_position = Vector3(-0.40, 1.50, 0.0)
		rh.global_position = Vector3(0.40, 1.50, 0.0)
		probe.global_position = Vector3(0.40, 1.50, 0.0)
		_check("Objek dekat tangan kanan diambil tangan kanan", ctrl._choose_hand(probe) == rh)
		probe.global_position = Vector3(-0.40, 1.50, 0.0)
		_check("Objek dekat tangan kiri diambil tangan kiri", ctrl._choose_hand(probe) == lh)

	# --- D. Tukar tangan (Q) ---------------------------------------------
	if probe != null:
		_hand_hold(lh, probe)
		_check("Tangan kiri memegang sachet", lh.holds == probe and probe.held_by == lh)
		ctrl.swap_hands()
		_check("Q menukar isi kedua tangan", rh.holds == probe and lh.holds == null)
		if rh.holds != null:
			rh.release_at(_home_world(rh.holds))
		if lh.holds != null:
			lh.release_at(_home_world(lh.holds))

	# --- E. Resep fisik (drag objek, bukan panel) -----------------------
	var brand: SachetBrand = null
	if catalog.brands.size() > 0:
		brand = catalog.brands[0]
	_check("Katalog punya brand sachet", brand != null)
	if brand == null:
		return
	inv.add_sachets(brand.id, 5)
	inv.add_ice(12)

	prep.open_build()
	_reset_prep_objects(objs)
	var steps := _cook_physical(prep, lh, rh, objs)
	_check("Langkah 'gunting potong sachet' terpicu", steps[0] == &"cut", "(dapat %s)" % steps[0])
	_check("Langkah 'serbub ke plastik' terpicu", steps[1] == &"pour_powder", "(dapat %s)" % steps[1])
	_check("Langkah 'tuang air' terpicu", steps[2] == &"pour_water", "(dapat %s)" % steps[2])
	_check("Langkah 'aduk' terpicu", steps[3] == &"stir", "(dapat %s)" % steps[3])
	_check("Langkah 'serok ambil es' terpicu", steps[4] == &"fill_scoop", "(dapat %s)" % steps[4])
	_check("Langkah 'es masuk plastik' terpicu", steps[5] == &"add_ice", "(dapat %s)" % steps[5])
	_check("Langkah 'pasang sedotan' terpicu", steps[6] == &"add_straw", "(dapat %s)" % steps[6])

	# --- F. Urutan langkah & skor ----------------------------------------
	var expected: Array[StringName] = [&"cut", &"pour_powder", &"pour_water", &"stir", &"add_ice", &"add_straw"]
	_check("Riwayat langkah sesuai urutan resep", prep.step_history == expected, "(dapat %s)" % str(prep.step_history))
	_check("Semua langkah wajib tercatat", prep.has_step(&"cut") and prep.has_step(&"pour_powder")
		and prep.has_step(&"pour_water") and prep.has_step(&"stir")
		and prep.has_step(&"add_ice") and prep.has_step(&"add_straw"))
	_check("Tidak ada langkah salah urutan", prep.out_of_order_count == 0, "(dapat %d)" % prep.out_of_order_count)
	_check("Resep dianggap lengkap", prep.is_complete())
	_check("Skor langkah sempurna", is_equal_approx(prep.step_score(), 1.0), "(dapat %.2f)" % prep.step_score())
	_check("Brand terambil dari sachet fisik", prep.selected_brand != null and prep.selected_brand.id == brand.id)

	# --- G. Langkah salah urutan -----------------------------------------
	prep.open_build()
	_reset_prep_objects(objs)
	var bad := _prep_step(prep, lh, rh, objs.get("Straw"), objs.get("PlasticBag"))
	_check("Bisa melakukan langkah di luar urutan", bad == &"add_straw", "(dapat %s)" % bad)
	_check("Langkah salah urutan dihitung", prep.out_of_order_count == 1, "(dapat %d)" % prep.out_of_order_count)
	_check("Penalti menurunkan kualitas", prep.step_score() < 1.0, "(dapat %.2f)" % prep.step_score())

	# --- H. Daftar yang kurang (dipakai komplain) ------------------------
	prep.open_build()
	_reset_prep_objects(objs)
	var missing := prep.missing_steps()
	_check("Resep kosong menyisakan 6 hal kurang", missing.size() == 6, "(dapat %d)" % missing.size())
	_check("... 'Belum ambil sachet!'", missing.has("Belum ambil sachet!"))
	_check("... 'Belum ada serbub sachet!'", missing.has("Belum ada serbub sachet!"))
	_check("... 'Belum dikasih air!'", missing.has("Belum dikasih air!"))
	_check("... 'Belum diaduk!'", missing.has("Belum diaduk!"))
	_check("... 'Belum ada es!'", missing.has("Belum ada es!"))
	_check("... 'Belum ada sedotannya!'", missing.has("Belum ada sedotannya!"))

	# --- I. Build tas memakai stok (Decision #1) -------------------------
	prep.open_build()
	_reset_prep_objects(objs)
	_cook_physical(prep, lh, rh, objs)
	var sachets_before := inv.sachet_stock.get(brand.id, 0) as int
	var ice_before := inv.ice_stock
	var bag := prep.build_bag()
	_check("Tas berhasil dibuat", bag != null)
	_check("1 sachet terpakai saat build", (inv.sachet_stock.get(brand.id, 0) as int) == sachets_before - 1)
	_check("Es terpakai saat build", inv.ice_stock == ice_before - 2, "(dapat %d)" % inv.ice_stock)

	# --- J. Pelanggan komplain saat es belum siap -----------------------
	prep.open_build()
	_reset_prep_objects(objs)
	prep.set_vessel(objs.get("PlasticBag"))
	var customer_scene := load("res://src/entities/Customer.tscn") as PackedScene
	_check("Scene pelanggan bisa dimuat", customer_scene != null)
	if customer_scene == null:
		return
	var customer := customer_scene.instantiate() as Customer
	loc_root.add_child(customer)
	customer.setup(brand, 1.0)
	customer.state = Customer.State.WAITING
	customer.global_position = stand.pickup_position()
	_complain_lines.clear()
	customer.complain.connect(_on_test_complain)

	# Controller dianggap berdiri di depan konter supaya pelanggan uji ini
	# yang paling dekat (tidak diganggu pelanggan lain).
	var player_pos := player.global_position
	player.global_position = stand.pickup_position()
	ctrl.session = prep
	ctrl.stand = stand
	ctrl.deliver_to_nearest_customer()
	_check("Pelanggan komplain saat es belum siap", _complain_lines.size() > 0)
	if _complain_lines.size() > 0:
		_check("Komplain diawali 'Kurang:'", _complain_lines[0].begins_with("Kurang:"))
		_check("Komplain menyebut bahan yang kurang",
			_complain_lines[0].contains("Belum ada es!") and _complain_lines[0].contains("Belum dikasih air!"))

	# --- K. Pelanggan ambil sendiri saat es siap ------------------------
	prep.open_build()
	_reset_prep_objects(objs)
	prep.set_vessel(objs.get("PlasticBag"))
	_cook_physical(prep, lh, rh, objs)
	_check("Es siap sebelum diserahkan", prep.is_complete())
	var money_before := inv.money
	ctrl._check_customer(0.0)
	_check("Pelanggan mengambil es sendiri", customer.state == Customer.State.SERVED,
		"(state %d)" % customer.state)
	_check("Uang bertambah setelah pelanggan ambil", inv.money > money_before, "(dapat %.1f)" % inv.money)
	_check("Tas sudah diambil dari meja", stand.current_bag == null)
	player.global_position = player_pos
	customer.queue_free()

	# --- L. Controller masuk & keluar mode prep --------------------------
	ctrl.enter(stand)
	_check("PrepController aktif setelah enter", ctrl.active and ctrl.session == prep)
	ctrl.exit()
	_check("PrepController nonaktif setelah exit", not ctrl.active)


# --- Task 16 — kontrol layar sentuh --------------------------------------

## Tes kontrol sentuh mode first-person.
## Yang diuji:
##   A. Semua objek meja masuk layar & bisa di-pick (bug kamera Task 15).
##   B. API pointer di PrepController (ambil / geser / lepas).
##   C. Routing event: mouse -> ambil, mouse -> lepas.
##   D. Takeover: mouse tiruan (Android) lalu jari di posisi sama.
##   E. Dua jari: jari kedua = melihat, bukan mengambil.
##   F. Satu jari di area kosong = melihat.
##   G. Tombol layar TUKAR TANGAN & PUTAR BADAN.
##   H. Aksi tombol benar-benar mengubah keadaan.
## Kembalikan objek & tangan ke keadaan awal: semua di meja, tangan kosong.
func _restore_prep_state(lh: Hand, rh: Hand, objs: Array[PrepObject]) -> void:
	for h in [lh, rh]:
		var hand := h as Hand
		if hand != null and hand.holds != null:
			hand.release_at(_home_world(hand.holds))
	for o in objs:
		if o != null:
			o.return_home()


## Cari objek + titik layar yang benar-benar bisa di-pick.
## `unproject_position` saja tidak cukup — objek lain bisa menghalangi.
## Mengembalikan [obj, Vector2] atau [] kalau tidak ada yang bisa diambil.
func _find_pick_point(ctrl: PrepController, objs: Array[PrepObject]) -> Array:
	if ctrl == null or ctrl.camera == null:
		return []
	# Prioritaskan objek yang tidak mengubah state sesi resep.
	var order: Array[StringName] = [&"Scissors", &"Spoon", &"Straw", &"IceScoop"]
	var ordered: Array[PrepObject] = []
	for n in order:
		for o in objs:
			if o != null and StringName(o.name) == n:
				ordered.append(o)
	for o in objs:
		if o != null and not ordered.has(o):
			ordered.append(o)
	for o in ordered:
		var sp := ctrl.camera.unproject_position(o.global_position)
		if sp.x < 4.0 or sp.y < 4.0:
			continue
		if ctrl.pick_object_at(sp) == o:
			return [o, sp]
	return []


## Titik layar yang memang kosong (tidak ada objek di bawahnya).
func _find_empty_point(ctrl: PrepController, vp: Vector2) -> Vector2:
	var candidates: Array[Vector2] = [
		Vector2(vp.x * 0.5, 40.0),
		Vector2(vp.x * 0.5, vp.y - 30.0),
		Vector2(30.0, 30.0),
		Vector2(vp.x - 30.0, 30.0),
	]
	for c in candidates:
		if ctrl.pick_object_at(c) == null:
			return c
	return Vector2(vp.x * 0.5, 40.0)


func _test_task16(loc_root: Node3D) -> void:
	var stand := _find_stand(loc_root)
	if stand == null:
		_fail("Stand tidak ada — Task 16 dilewati.")
		return
	var players := get_tree().get_nodes_in_group("player")
	var player: Player = players[0] if players.size() > 0 else null
	if player == null:
		_fail("Player tidak ada — Task 16 dilewati.")
		return
	var ctrl := player.get_node_or_null("PrepController") as PrepController
	var lh := player.get_node_or_null("PrepRig/LeftHand") as Hand
	var rh := player.get_node_or_null("PrepRig/RightHand") as Hand
	_check("PrepController punya API pointer sentuh",
		ctrl != null and ctrl.has_method("begin_drag_at")
		and ctrl.has_method("end_drag_at")
		and ctrl.has_method("set_pointer"))
	if ctrl == null or lh == null or rh == null:
		return

	# Masuk mode prep supaya rig first-person & kamera aktif.
	player.global_position = stand.pickup_position()
	player.enter_prep_mode(stand)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("Player masuk mode PREP", player.state == Player.State.PREP)

	# --- A. Semua objek meja harus terlihat & bisa di-pick ---------------
	# (Bug Task 15: kamera terlalu dekat meja -> objek jatuh di luar layar
	#  sehingga tidak bisa di-drag sama sekali.)
	var objs: Array[PrepObject] = []
	for c in stand.prep_station.get_children():
		var o := c as PrepObject
		if o != null:
			objs.append(o)
	_restore_prep_state(lh, rh, objs)
	await get_tree().physics_frame

	var vp := get_viewport().get_visible_rect().size
	var offscreen: Array[String] = []
	for o in objs:
		var sp := ctrl.camera.unproject_position(o.global_position)
		if sp.x < 0.0 or sp.y < 0.0 or sp.x > vp.x or sp.y > vp.y:
			offscreen.append(String(o.name))
	_check("Seluruh objek meja terlihat di layar first-person", offscreen.is_empty(),
		"(di luar layar: %s)" % ", ".join(offscreen))

	var pick := _find_pick_point(ctrl, objs)
	_check("Ada objek yang bisa diambil lewat layar", not pick.is_empty())
	if pick.is_empty():
		player.exit_prep_mode()
		await get_tree().process_frame
		return
	var target_obj: PrepObject = pick[0]
	var target_pos: Vector2 = pick[1]
	var empty_pos := _find_empty_point(ctrl, vp)
	_check("Area kosong di layar tidak menimpa objek",
		ctrl.pick_object_at(empty_pos) == null)
	_check("Objek sasaran terbaca lewat ray-pick",
		ctrl.pick_object_at(target_pos) == target_obj)

	# --- B. API pointer di PrepController --------------------------------
	var grabbed := ctrl.begin_drag_at(target_pos)
	_check("Sentuhan di objek mengambilnya", grabbed)
	_check("Status dragging aktif", ctrl.dragging)
	_check("Salah satu tangan memegang objek", lh.holds != null or rh.holds != null)
	ctrl.set_pointer(target_pos)
	_check("Geser pointer tidak memutus grab",
		ctrl.dragging and (lh.holds != null or rh.holds != null))
	ctrl.end_drag_at(target_pos)
	_check("Lepas pointer mengembalikan objek ke meja",
		not ctrl.dragging and lh.holds == null and rh.holds == null)
	_check("Sentuhan di area kosong tidak mengambil", not ctrl.begin_drag_at(empty_pos))
	_restore_prep_state(lh, rh, objs)
	await get_tree().physics_frame

	# --- C. Routing event: mouse ----------------------------------------
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = target_pos
	player.handle_prep_pointer(mb)
	_check("Klik mouse pada objek mengambilnya", ctrl.dragging)
	var mb_up := InputEventMouseButton.new()
	mb_up.button_index = MOUSE_BUTTON_LEFT
	mb_up.pressed = false
	mb_up.position = target_pos
	player.handle_prep_pointer(mb_up)
	_check("Lepas mouse mengembalikan objek ke meja",
		not ctrl.dragging and lh.holds == null and rh.holds == null)
	var mb_empty := InputEventMouseButton.new()
	mb_empty.button_index = MOUSE_BUTTON_LEFT
	mb_empty.pressed = true
	mb_empty.position = empty_pos
	player.handle_prep_pointer(mb_empty)
	_check("Klik mouse di area kosong tidak mengambil", not ctrl.dragging)
	_restore_prep_state(lh, rh, objs)
	await get_tree().physics_frame

	# --- D. Takeover mouse tiruan -> jari --------------------------------
	# Android mengirim mouse tiruan lebih dulu, baru event sentuh asli.
	var mb_drag := InputEventMouseButton.new()
	mb_drag.button_index = MOUSE_BUTTON_LEFT
	mb_drag.pressed = true
	mb_drag.position = target_pos
	player.handle_prep_pointer(mb_drag)
	_check("Mouse tiruan mengambil objek", ctrl.dragging)
	var st_takeover := InputEventScreenTouch.new()
	st_takeover.index = 0
	st_takeover.pressed = true
	st_takeover.position = target_pos
	player.handle_prep_pointer(st_takeover)
	_check("Jari di posisi klik mengambil alih drag", ctrl.dragging)
	# Geser jari -> objek ikut bergerak, bukan memutar pandangan.
	var pitch_before := player._pitch
	var sd := InputEventScreenDrag.new()
	sd.index = 0
	sd.position = target_pos + Vector2(40.0, -20.0)
	sd.relative = Vector2(40.0, -20.0)
	player.handle_prep_pointer(sd)
	_check("Geser jari menggerakkan objek yang dipegang",
		ctrl.dragging and (lh.holds != null or rh.holds != null))
	_check("Geser jari saat drag tidak memutar pandangan",
		is_equal_approx(player._pitch, pitch_before))
	var st_release := InputEventScreenTouch.new()
	st_release.index = 0
	st_release.pressed = false
	st_release.position = sd.position
	player.handle_prep_pointer(st_release)
	_check("Lepas jari mengembalikan objek ke meja",
		not ctrl.dragging and lh.holds == null and rh.holds == null)
	_restore_prep_state(lh, rh, objs)
	await get_tree().physics_frame

	# --- E. Dua jari: jari kedua untuk melihat ---------------------------
	var st1 := InputEventScreenTouch.new()
	st1.index = 0
	st1.pressed = true
	st1.position = target_pos
	player.handle_prep_pointer(st1)
	_check("Jari pertama di objek mengambilnya", ctrl.dragging)
	var st2 := InputEventScreenTouch.new()
	st2.index = 1
	st2.pressed = true
	st2.position = empty_pos
	player.handle_prep_pointer(st2)
	_check("Jari kedua di area kosong tidak mengambil objek", ctrl.dragging)
	var st2_release := InputEventScreenTouch.new()
	st2_release.index = 1
	st2_release.pressed = false
	st2_release.position = empty_pos
	player.handle_prep_pointer(st2_release)
	_check("Lepas jari kedua tidak menempelkan objek", ctrl.dragging)
	var st1_release := InputEventScreenTouch.new()
	st1_release.index = 0
	st1_release.pressed = false
	st1_release.position = target_pos
	player.handle_prep_pointer(st1_release)
	_check("Lepas jari pertama mengembalikan objek ke meja",
		not ctrl.dragging and lh.holds == null and rh.holds == null)
	_restore_prep_state(lh, rh, objs)
	await get_tree().physics_frame

	# --- F. Satu jari di area kosong = melihat ---------------------------
	var yaw_before := player._yaw
	var st_look := InputEventScreenTouch.new()
	st_look.index = 0
	st_look.pressed = true
	st_look.position = empty_pos
	player.handle_prep_pointer(st_look)
	_check("Satu jari di area kosong tidak mengambil objek", not ctrl.dragging)
	var sd_look := InputEventScreenDrag.new()
	sd_look.index = 0
	sd_look.position = empty_pos + Vector2(30.0, 0.0)
	sd_look.relative = Vector2(30.0, 0.0)
	player.handle_prep_pointer(sd_look)
	_check("Satu jari di area kosong memutar pandangan",
		not is_equal_approx(player._yaw, yaw_before))
	var st_look_release := InputEventScreenTouch.new()
	st_look_release.index = 0
	st_look_release.pressed = false
	st_look_release.position = sd_look.position
	player.handle_prep_pointer(st_look_release)
	_check("Lepas jari pengamat tidak grabbing apa pun", not ctrl.dragging)

	# --- G. Tombol layar TUKAR TANGAN & PUTAR BADAN ---------------------
	var seen: Dictionary = {}
	var on_action := func(action: StringName, _value: float) -> void:
		seen[action] = true
	UILayer.prep_action.connect(on_action)
	UILayer.prep_action.emit(UILayer.ACTION_SWAP_HAND, 0.0)
	_check("Tombol TUKAR TANGAN mengirim ACTION_SWAP_HAND", seen.has(UILayer.ACTION_SWAP_HAND))
	var body_yaw_before := player._body_yaw
	UILayer.prep_action.emit(UILayer.ACTION_TURN_BODY, 0.0)
	_check("Tombol PUTAR BADAN mengirim ACTION_TURN_BODY", seen.has(UILayer.ACTION_TURN_BODY))
	_check("Tombol PUTAR BADAN memutar badan",
		not is_equal_approx(player._body_yaw, body_yaw_before))
	if UILayer.prep_action.is_connected(on_action):
		UILayer.prep_action.disconnect(on_action)

	# --- H. Aksi tombol benar-benar mengubah keadaan ---------------------
	var probe := stand.prep_station.get_node_or_null("Sachet_1") as PrepObject
	if probe != null:
		_hand_hold(lh, probe)
		UILayer.prep_action.emit(UILayer.ACTION_SWAP_HAND, 0.0)
		_check("Tukar tangan lewat tombol layar pindah isi tangan", rh.holds == probe and lh.holds == null)
		if rh.holds != null:
			rh.release_at(_home_world(rh.holds))
	else:
		_check("Objek sachet tersedia untuk tes tukar tangan", false)

	# Keluar dari mode prep supaya test lain tidak terpengaruh.
	player.exit_prep_mode()
	await get_tree().process_frame
	_check("Keluar dari mode prep", player.state != Player.State.PREP)


# --- Task 7 -------------------------------------------------------------

func _test_task7(loc_root: Node3D) -> void:
	var stand := _find_stand(loc_root)
	if stand == null:
		_fail("Stand tidak ada — Task 7 dilewati.")
		return
	var spawner := stand.spawner
	_check("Stand terhubung ke CustomerSpawner", spawner != null)
	if spawner == null:
		return

	var prep := stand.prep_station
	var inv: Inventory = get_tree().root.get_node_or_null("Inventory")
	var catalog: Catalog = get_tree().root.get_node_or_null("Catalog")

	# --- Spawning ---
	var spawned := spawner.try_spawn()
	_check("Customer berhasil spawn", spawned)
	_check("Spawner melacak 1 customer", spawner.customers.size() == 1,
		"(dapat %d)" % spawner.customers.size())
	if spawner.customers.is_empty():
		_fail("Tidak ada customer untuk diuji.")
		return

	var customer := spawner.customers[0] as Customer
	_check("Customer punya pesanan", customer.order_brand != null)
	_check("Customer punya price tolerance", customer.price_tolerance > 0.0,
		"(dapat %.0f)" % customer.price_tolerance)

	# Simulate the customer having arrived at the seat.
	customer.global_position = customer.target_position
	customer.state = Customer.State.WAITING
	_check("Customer adalah customer pertama", spawner.next_customer() == customer)

	# --- Serve the correct brand ---
	prep.open_build()
	prep.select_brand(customer.order_brand)
	prep.pour(1.0)
	prep.add_water()
	prep.stir()
	prep.add_ice(4)
	prep.add_straw()
	var order_bag := prep.build_bag()
	stand.offer_bag(order_bag)
	var money_before := inv.money
	var result := stand.serve_offered_to(customer)
	_check("Es yang benar diterima", bool(result.get("accepted", false)),
		"(%s)" % str(result.get("line", "")))
	_check("Pelanggan membayar", inv.money > money_before,
		"(dapat %.0f)" % inv.money)
	_check("Ada tip untuk es berkualitas", float(result.get("tip", 0.0)) > 0.0,
		"(dapat %.0f)" % float(result.get("tip", 0.0)))
	_check("Satisfaction > 0", float(result.get("satisfaction", 0.0)) > 0.0,
		"(dapat %.2f)" % float(result.get("satisfaction", 0.0)))
	_check("Uang masuk = harga + tip",
		is_equal_approx(inv.money - money_before,
			order_bag.sell_price + float(result.get("tip", 0.0))))

	# --- Wrong brand is refused ---
	var other: SachetBrand = null
	for b in catalog.brands:
		if b.id != customer.order_brand.id:
			other = b
			break
	prep.open_build()
	prep.select_brand(other)
	prep.pour(1.0)
	prep.add_water()
	prep.stir()
	prep.add_ice(4)
	prep.add_straw()
	var wrong_bag := prep.build_bag()
	stand.offer_bag(wrong_bag)
	var money_before2 := inv.money
	var annoyance_before := customer.annoyance_level
	var result2 := stand.serve_offered_to(customer)
	_check("Brand salah ditolak", bool(result2.get("refused", false)),
		"(%s)" % str(result2.get("line", "")))
	_check("Brand salah tidak dibayar", is_equal_approx(inv.money, money_before2),
		"(dapat %.0f, harusnya %.0f)" % [inv.money, money_before2])
	_check("Brand salah menaikkan annoyance", customer.annoyance_level > annoyance_before,
		"(dapat %.2f)" % customer.annoyance_level)

	# --- Overprice: still pays, but no tip ---
	prep.open_build()
	prep.select_brand(customer.order_brand)
	prep.pour(1.0)
	prep.add_water()
	prep.stir()
	prep.add_ice(4)
	prep.add_straw()
	var pricey_bag := prep.build_bag()
	pricey_bag.sell_price = pricey_bag.cost() * 2.0
	stand.offer_bag(pricey_bag)
	var money_before3 := inv.money
	var result3 := stand.serve_offered_to(customer)
	_check("Overprice tetap dibayar", inv.money > money_before3,
		"(dapat %.0f)" % inv.money)
	_check("Overprice tidak dapat tip", is_equal_approx(float(result3.get("tip", -1.0)), 0.0),
		"(dapat %.0f)" % float(result3.get("tip", -1.0)))
	_check("Overprice tetap diterima", bool(result3.get("accepted", false)))

	# --- Annoyance escalation tiers ---
	var complaints: Array[String] = []
	customer.complain.connect(func(line: String, _level: float) -> void:
		complaints.append(line)
	)
	customer.annoyance_rate = 1.0
	customer.annoyance_level = 0.59
	customer.last_complaint_tier = -1
	complaints.clear()
	customer._tick_annoyance(6.0)
	_check("Keluhan pada tier 0.60", complaints.size() == 1
		and complaints[0] == "Mau es apa berak bang?",
		"(dapat %s)" % str(complaints))

	complaints.clear()
	customer.annoyance_level = 0.99
	customer._tick_annoyance(45.0)
	_check("Keluhan pada tier 1.00", complaints.size() == 1
		and complaints[0] == "Berhenti main HP, bang!",
		"(dapat %s)" % str(complaints))
	_check("Annoyance maksimal 1.0", is_equal_approx(customer.annoyance_level, 1.0))

	# --- The stand never exceeds seats + max_queue ---
	var guard := 0
	while spawner.try_spawn() and guard < 30:
		guard += 1
	var seated := 0
	var queued := 0
	for c in spawner.customers:
		if c == null or not is_instance_valid(c):
			continue
		if c.state == Customer.State.LEAVING or c.state == Customer.State.SERVED:
			continue
		if c.is_seated:
			seated += 1
		else:
			queued += 1
	_check("Spawn berhenti saat stand penuh", not spawner.try_spawn())
	_check("Tidak melebihi kapasitas stand",
		seated <= spawner.location_def.seats and queued <= spawner.location_def.max_queue,
		"(duduk %d/%d, antre %d/%d)" % [seated, spawner.location_def.seats,
			queued, spawner.location_def.max_queue])


# --- Task 8 ---------------------------------------------------------------

func _test_task8(loc_root: Node3D) -> void:
	var inv: Inventory = get_tree().root.get_node_or_null("Inventory")
	var catalog: Catalog = get_tree().root.get_node_or_null("Catalog")
	var ui_layer := get_tree().root.get_node_or_null("UILayer") as UILayer
	var econ := get_tree().root.get_node_or_null("Economy")
	if inv == null or catalog == null:
		_fail("Autoload Catalog/Inventory hilang — Task 8 dilewati.")
		return

	# --- Slot bookkeeping -------------------------------------------------
	_check("Startup tool kecil ada di slot 'cooler'",
		inv.tool_in_slot(&"cooler") != null
		and inv.tool_in_slot(&"cooler").id == &"ice_cooler_small")
	_check("Quality mod total = 1.0", is_equal_approx(inv.total_quality_mod(), 1.0),
		"(dapat %.2f)" % inv.total_quality_mod())
	_check("Kapasitas es total = 8", inv.total_ice_capacity() == 8,
		"(dapat %d)" % inv.total_ice_capacity())

	# --- Buying an upgrade replaces the tool in the same slot ------------
	var big: Tool = catalog.tool_by_id(&"ice_cooler_large")
	_check("Catalog punya ice_cooler_large", big != null)
	if big == null:
		return

	# The upgrade unlocks on day 2 — check the unlock gate first.
	_check("ice_cooler_large terkunci di hari 1",
		not catalog.available_on_day(1).any(func(t): return t.id == &"ice_cooler_large"))
	_check("ice_cooler_large terbuka di hari 2",
		catalog.available_on_day(2).any(func(t): return t.id == &"ice_cooler_large"))

	# Give the player enough cash and buy it.
	inv.money = 500000.0
	var money_before_buy: float = inv.money
	var bought: bool = inv.buy_tool(big)
	_check("Beli upgrade berhasil", bought)
	_check("Beli upgrade mengurangi uang",
		is_equal_approx(inv.money, money_before_buy - big.cost),
		"(dapat %.0f, harusnya %.0f)" % [inv.money, money_before_buy - big.cost])
	_check("Cooler besar menggantikan yang kecil di slot 'cooler'",
		inv.tool_in_slot(&"cooler") != null
		and inv.tool_in_slot(&"cooler").id == &"ice_cooler_large")
	var cooler_count: int = 0
	for t in inv.owned_tools:
		if t.slot == &"cooler":
			cooler_count += 1
	_check("Tidak ada dua tool di slot yang sama", cooler_count == 1,
		"(dapat %d)" % cooler_count)
	_check("Kapasitas es jadi 16", inv.total_ice_capacity() == 16,
		"(dapat %d)" % inv.total_ice_capacity())
	_check("Quality mod naik jadi 1.2", is_equal_approx(inv.total_quality_mod(), 1.2),
		"(dapat %.2f)" % inv.total_quality_mod())

	# Buying the same tool twice must fail.
	_check("Tidak bisa beli tool yang sama dua kali", not inv.buy_tool(big))

	# --- The stand picks the upgrade up immediately ----------------------
	var stand := _find_stand(loc_root)
	if stand != null:
		_check("Stand memakai cooler besar",
			stand.equipment.ice_capacity() == 16,
			"(dapat %d)" % stand.equipment.ice_capacity())
		_check("StandEquipment quality mod = 1.2",
			is_equal_approx(stand.equipment.quality_mod(), 1.2),
			"(dapat %.2f)" % stand.equipment.quality_mod())

	# --- Shop panel --------------------------------------------------------
	if ui_layer != null:
		ui_layer.open_shop()
		_check("Panel toko terbuka", ui_layer.is_shop_panel_open())
		var rows := ui_layer.get("_shop_tools") as Array
		_check("Toko punya upgrade cooler besar",
			rows.any(func(t): return (t as Tool).id == &"ice_cooler_large"))
		ui_layer.close_shop()
		_check("Panel toko tertutup", not ui_layer.is_shop_panel_open())

	# --- Per-location rent --------------------------------------------------
	if econ != null:
		var pasar: LocationDef = catalog.location_by_id(&"pasar")
		var rumah: LocationDef = catalog.location_by_id(&"rumah")
		_check("Sewa Pasar = 30", pasar != null and is_equal_approx(pasar.rent_cost, 30.0))
		_check("Sewa Rumah = 15", rumah != null and is_equal_approx(rumah.rent_cost, 15.0))

		econ.record_sale(&"tejus", &"pasar", 5000.0)
		var money_before_rent: float = inv.money
		var rent: float = econ.charge_rent(&"pasar")
		_check("Sewa Pasar tertagih 30", is_equal_approx(rent, 30.0),
			"(dapat %.0f)" % rent)
		_check("Sewa mengurangi uang",
			is_equal_approx(inv.money, money_before_rent - 30.0),
			"(dapat %.0f)" % inv.money)
		_check("Sewa lokasi sama tidak ditagih dua kali",
			is_equal_approx(econ.charge_rent(&"pasar"), 0.0))


# --- Task 9 -------------------------------------------------------------

## Task 9: the UILayer polish — the live order queue, the desktop price
## slider and the richer day-end recap.
func _test_task9(loc_root: Node3D) -> void:
	var ui_layer := get_tree().root.get_node_or_null("UILayer") as UILayer
	if ui_layer == null:
		_fail("Autoload UILayer hilang — Task 9 dilewati.")
		return

	# --- The order queue panel -------------------------------------------
	var rows_box := ui_layer.get("_order_rows_box") as VBoxContainer
	var queue_label := ui_layer.get("_order_queue_label") as Label
	_check("Panel antrian ada di UILayer", rows_box != null and queue_label != null)
	if rows_box == null or queue_label == null:
		return

	var waiting := ui_layer.waiting_customers()
	var all_customers := true
	for c in waiting:
		if not (c is Customer):
			all_customers = false
	_check("Antrean hanya berisi object Customer", all_customers)

	ui_layer.refresh_order_queue()
	_check("Jumlah baris antrian = pelanggan yang menunggu",
		rows_box.get_child_count() == waiting.size(),
		"(baris %d, menunggu %d)" % [rows_box.get_child_count(), waiting.size()])
	_check("Judul antrian menyebut jumlah orang",
		queue_label.text.begins_with("Antrian: %d" % waiting.size()),
		"(teks '%s')" % queue_label.text)

	# --- The day bar follows TimeOfDay ------------------------------------
	var day_bar := ui_layer.get("_day_bar") as ProgressBar
	_check("Progress bar hari ada", day_bar != null)
	if day_bar != null:
		ui_layer._on_time_tick(90.0, 0.5)
		_check("Progress bar hari mengikuti waktu TimeOfDay",
			is_equal_approx(day_bar.value, 0.5),
			"(nilai %.3f)" % day_bar.value)

	# --- The desktop price slider ----------------------------------------
	var slider := ui_layer.get("_price_slider") as HSlider
	_check("Slider harga dibuat", slider != null)
	var stand := _find_stand(loc_root)
	if slider != null and stand != null:
		var catalog: Catalog = get_tree().root.get_node_or_null("Catalog")
		var brand: SachetBrand = null
		if catalog != null and catalog.brands.size() > 0:
			brand = catalog.brands[0]
		if brand != null:
			var prep := stand.prep_station
			prep.open_build()
			prep.select_brand(brand)
			prep.pour(1.0)
			prep.add_water()
			prep.stir()
			prep.add_ice(4)
			prep.add_straw()
			var bag := prep.build_bag()
			_check("Bisa membuat tas untuk tes slider", bag != null)
			if bag != null:
				stand.offer_bag(bag)
				ui_layer.update_prep(stand.snapshot())
				_check("Slider harga terlihat saat ada tas", slider.visible)
				_check("Batas bawah slider = modal",
					is_equal_approx(slider.min_value, minf(bag.cost(), bag.fair_price_min())),
					"(dapat %.0f, modal %.0f)" % [slider.min_value, bag.cost()])
				# The slider must show exactly the price that is charged.
				_check("Nilai slider = harga tas",
					absf(slider.value - bag.sell_price) <= 0.05,
					"(slider %.2f, harga %.2f)" % [slider.value, bag.sell_price])
				# Regression: updating the slider must never overwrite the
				# price of the bag with the cost of the ingredients.
				_check("Slider tidak menimpa harga tas",
					is_equal_approx(bag.sell_price, bag.recommended_price()),
					"(dapat %.2f, harusnya %.2f)" % [bag.sell_price, bag.recommended_price()])

				# The price may never drop below the cost of the ingredients.
				stand._set_price(1.0)
				_check("Harga tidak boleh di bawah modal",
					is_equal_approx(bag.sell_price, bag.cost()),
					"(dapat %.0f, modal %.0f)" % [bag.sell_price, bag.cost()])

				# The slider drives the stand through the prep_action signal.
				ui_layer.prep_action.emit(UILayer.ACTION_PRICE_SET, 25000.0)
				_check("Slider harga mengubah harga di stand",
					is_equal_approx(bag.sell_price, 25000.0),
					"(dapat %.0f)" % bag.sell_price)
				stand.take_bag()

	# --- The richer day-end recap ------------------------------------------
	var detail := ui_layer.get("_day_end_detail") as Label
	_check("Label detail rekap harian ada", detail != null)
	if detail != null:
		ui_layer.show_day_end({
			"day": 3,
			"revenue": 25000.0,
			"expenses": 10000.0,
			"profit": 15000.0,
			"best_brand": "Tejus",
			"sales": 5,
			"location_profit": {"pasar": 12000.0},
			"rent_by_location": {"pasar": 30.0},
			"new_unlocks": [],
		})
		_check("Detail rekap menampilkan laba per lokasi",
			detail.text.contains("Laba per lokasi"),
			"(teks '%s')" % detail.text)
		_check("Detail rekap menampilkan nama lokasi",
			detail.text.contains("Pasar"),
			"(teks '%s')" % detail.text)
		_check("Detail rekap menampilkan sewa",
			detail.text.contains("Sewa"),
			"(teks '%s')" % detail.text)
	# Hide the panel again so it does not block the rest of the run.
	var panel := ui_layer.get("_day_end_panel") as Control
	if panel != null:
		panel.visible = false


# --- Task 4 (lighting) --------------------------------------------------

## Pencahayaan siang/malam yang BENAR-benar mengubah matahari + langit.
func _test_timeofday_lighting() -> void:
	var tod := get_tree().root.get_node_or_null("TimeOfDay")
	_check("Autoload TimeOfDay ada", tod != null)
	if tod == null:
		return

	var sun := tod.get("sun_light") as DirectionalLight3D
	var world_env := tod.get("environment") as WorldEnvironment
	_check("TimeOfDay memegang sun_light", sun != null)
	_check("TimeOfDay memegang environment", world_env != null)
	if sun == null or world_env == null:
		return

	# --- Siang: matahari terang ---
	tod.apply_lighting(0.45)
	var noon_energy: float = sun.light_energy
	var noon_color: Color = sun.light_color
	var noon_pitch: float = sun.rotation_degrees.x
	_check("Matahari terang saat siang", noon_energy > 0.8, "(energi %.2f)" % noon_energy)
	_check("Matahari berwarna terang saat siang", noon_color.get_luminance() > 0.5,
		"(warna %s)" % noon_color)

	# --- Malam: matahari redup ---
	tod.apply_lighting(1.0)
	var night_energy: float = sun.light_energy
	var night_color: Color = sun.light_color
	_check("Matahari redup saat malam", night_energy < 0.3, "(energi %.2f)" % night_energy)
	_check("Malam lebih gelap dari siang", night_energy < noon_energy)
	_check("Warna malam berbeda dari siang", not night_color.is_equal_approx(noon_color),
		"(malam %s, siang %s)" % [night_color, noon_color])
	_check("Sudut matahari berubah antara siang dan malam",
		not is_equal_approx(noon_pitch, sun.rotation_degrees.x),
		"(siang %.1f, malam %.1f)" % [noon_pitch, sun.rotation_degrees.x])

	# --- Langit juga berubah ---
	var env := world_env.environment
	_check("Environment punya sky", env != null and env.sky != null)
	if env != null and env.sky != null:
		var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
		_check("Sky material = ProceduralSkyMaterial", sky_mat != null)
		if sky_mat != null:
			tod.apply_lighting(0.45)
			var noon_top: Color = sky_mat.sky_top_color
			tod.apply_lighting(1.0)
			var night_top: Color = sky_mat.sky_top_color
			_check("Warna langit atas berubah siang vs malam",
				not noon_top.is_equal_approx(night_top),
				"(siang %s, malam %s)" % [noon_top, night_top])
			_check("Langit siang lebih terang dari langit malam",
				noon_top.get_luminance() > night_top.get_luminance(),
				"(siang %.3f, malam %.3f)" % [noon_top.get_luminance(), night_top.get_luminance()])

	# --- Aksen per lokasi hanya menggeser warna sedikit ---
	tod.apply_lighting(0.45)
	var tint_before: Color = sun.light_color
	tod.set_sun_tint(Color(1, 0, 0))
	tod.apply_lighting(0.45)
	var tint_after: Color = sun.light_color
	_check("Aksen lokasi mengubah warna matahari",
		not tint_before.is_equal_approx(tint_after),
		"(sebelum %s, sesudah %s)" % [tint_before, tint_after])
	tod.set_sun_tint(Color(1, 1, 1))


# --- Task 12 (3D feedback) -----------------------------------------------

## Visual 3D: tas di meja, bubble keluhan, dan pose kesal.
func _test_task12_feedback(loc_root: Node3D) -> void:
	var stand := _find_stand(loc_root)
	_check("Stand ada untuk tes visual", stand != null)
	if stand == null:
		return

	# --- Tas di meja ---
	var bag_visual := stand.get("bag_visual") as Node3D
	var bag_liquid := stand.get("bag_liquid") as MeshInstance3D
	var bag_straw := stand.get("bag_straw") as MeshInstance3D
	_check("Node BagVisual ada di stand", bag_visual != null)
	_check("Node Liquid ada di stand", bag_liquid != null)
	_check("Node Straw ada di stand", bag_straw != null)
	if bag_visual == null or bag_liquid == null or bag_straw == null:
		return
	_check("Tas tersembunyi saat tidak ada tas di meja", not bag_visual.visible)

	var catalog: Catalog = get_tree().root.get_node_or_null("Catalog")
	if catalog == null or catalog.brands.is_empty():
		_fail("Catalog tidak ada - tes visual dilewati.")
		return
	# Pakai brand termahal (5k) supaya prep_quality bisa tinggi.
	var brand: SachetBrand = catalog.brands[0]
	for b in catalog.brands:
		if b.price_tier >= brand.price_tier:
			brand = b
	_check("Brand 5k tersedia untuk tes visual", brand.price_tier == 5000,
		"(tier %d)" % brand.price_tier)

	# Pastikan stok cukup (es + sachet) untuk dua tas.
	Inventory.add_ice(20)
	Inventory.add_sachets(brand.id, 5)

	# --- Tas yang dibuat sempurna (tanpa es) ---
	# Tanpa es tidak ada efek memucatkan, jadi warna liquid harus persis
	# warna brand selama kualitasnya di atas batas "keruh".
	var prep := stand.prep_station
	prep.open_build()
	prep.select_brand(brand)
	prep.pour(1.0)
	prep.add_water()
	prep.stir()
	prep.add_straw()
	var good_bag := prep.build_bag()
	_check("Bisa membuat tas sempurna untuk tes visual", good_bag != null)
	if good_bag == null:
		return
	stand.offer_bag(good_bag)
	_check("Tas muncul di meja", bag_visual.visible)
	_check("Tas sempurna punya prep_quality tinggi", good_bag.prep_quality >= 60,
		"(kualitas %d)" % good_bag.prep_quality)

	var mat := bag_liquid.material_override as StandardMaterial3D
	_check("Material liquid tas dibuat", mat != null)
	var good_color := Color(0, 0, 0, 1)
	if mat != null:
		good_color = mat.albedo_color
		_check("Warna liquid tas sempurna sama dengan warna brand",
			good_color.is_equal_approx(brand.color_tint),
			"(liquid %s, brand %s)" % [good_color, brand.color_tint])
	_check("Tas sempurna ada sedotannya", bag_straw.visible)
	_check("Volume penuh -> liquid tinggi", bag_liquid.scale.y > 0.9,
		"(skala %.2f)" % bag_liquid.scale.y)

	# --- Tas dengan es: warna liquid jadi lebih pucat ---
	prep.open_build()
	prep.select_brand(brand)
	prep.pour(1.0)
	prep.add_water()
	prep.stir()
	prep.add_ice(4)
	prep.add_straw()
	var iced_bag := prep.build_bag()
	_check("Bisa membuat tas beres untuk tes visual", iced_bag != null)
	if iced_bag != null:
		stand.offer_bag(iced_bag)
		var iced_color := Color(0, 0, 0, 1)
		if mat != null:
			iced_color = mat.albedo_color
		_check("Es membuat warna liquid lebih pucat",
			iced_color.get_luminance() > good_color.get_luminance(),
			"(es %s, tanpa es %s)" % [iced_color, good_color])

	# --- Tas asal-asalan: kualitas rendah -> warna pudar ---
	prep.open_build()
	prep.select_brand(brand)
	prep.pour(0.2)
	var bad_bag := prep.build_bag()
	_check("Bisa membuat tas asal-asalan untuk tes visual", bad_bag != null)
	if bad_bag != null:
		stand.offer_bag(bad_bag)
		var bad_color := Color(0, 0, 0, 1)
		if mat != null:
			bad_color = mat.albedo_color
		_check("Tas asal-asalan lebih pucat dari tas sempurna",
			bad_color.s < good_color.s,
			"(buruk %s, bagus %s)" % [bad_color, good_color])
		_check("Volume sedikit -> liquid pendek", bag_liquid.scale.y < 0.6,
			"(skala %.2f)" % bag_liquid.scale.y)
		_check("Tas asal-asalan tanpa sedotan", not bag_straw.visible)

	# --- Tas diambil dari meja -> hilang ---
	stand.take_bag()
	_check("Tas hilang dari meja setelah diambil", not bag_visual.visible)

	# --- Bubble keluhan + pose kesal ---
	var customer_scene: PackedScene = load("res://src/entities/Customer.tscn")
	_check("Scene Customer bisa dimuat", customer_scene != null)
	if customer_scene == null:
		return
	var customer := customer_scene.instantiate() as Customer
	_check("Customer ter-instantiate dari scene", customer != null)
	if customer == null:
		return
	loc_root.add_child(customer)

	var bubble := customer.bubble
	_check("Pelanggan punya bubble 3D", bubble != null)
	if bubble != null:
		_check("Bubble tersembunyi saat tidak ada keluhan", not bubble.visible)
		customer.show_bubble("Lama amat, bang...")
		_check("Bubble muncul saat keluhan", bubble.visible)
		_check("Bubble berisi teks keluhan", bubble.text.contains("Lama amat"),
			"(teks '%s')" % bubble.text)
		customer.update_feedback(Customer.BUBBLE_TIME + 0.1)
		_check("Bubble hilang setelah waktunya habis", not bubble.visible)
		# Sinyal complain harus otomatis memunculkan bubble.
		customer.complain.emit("Mau es apa berak bang?", 0.6)
		_check("Sinyal complain memunculkan bubble", bubble.visible)

	var body := customer.body
	_check("Pelanggan punya badan 3D", body != null)
	if body != null:
		customer.annoyance_level = 0.0
		customer.apply_pose(0.0)
		_check("Pose netral -> badan tegak", is_equal_approx(body.scale.y, 1.0),
			"(skala %.2f)" % body.scale.y)
		_check("Belum kesal -> tidak jongkok", customer.target_crouch() == 0.0,
			"(target %.2f)" % customer.target_crouch())
		customer.annoyance_level = 0.65
		_check("Kesal sedang -> jongkok separuh", customer.target_crouch() >= 0.5,
			"(target %.2f)" % customer.target_crouch())
		customer.annoyance_level = 1.0
		_check("Maksimal kesal -> jongkok penuh", customer.target_crouch() >= 0.9,
			"(target %.2f)" % customer.target_crouch())
		customer.apply_pose(customer.target_crouch())
		_check("Pose kesal -> badan memendek", body.scale.y < 0.9,
			"(skala %.2f)" % body.scale.y)
		var body_mat := body.material_override as StandardMaterial3D
		_check("Pose kesal -> badan punya material sendiri", body_mat != null)
		if body_mat != null:
			_check("Pose kesal -> badan makin merah",
				body_mat.albedo_color.r > Customer.BODY_COLOR.r,
				"(warna %s)" % body_mat.albedo_color)
		# Pelanggan yang sudah dilayani tidak lagi jongkok.
		customer.state = Customer.State.SERVED
		_check("Pelanggan yang dilayani tegak lagi", customer.target_crouch() == 0.0,
			"(target %.2f)" % customer.target_crouch())

	customer.queue_free()


## Task 11 — virtual joystick (Android) harus benar-benar menggerakkan pemain.
## Regresi untuk bug lama: `_find_ui_layer()` mencari method `set_move_vector`
## yang tidak pernah ada, sehingga vektor gerak tidak pernah sampai ke Player.
func _test_virtual_joystick() -> void:
	var ui := get_tree().root.get_node_or_null("UILayer")
	_check("Autoload UILayer ada (joystick)", ui != null)
	if ui == null:
		return

	_check("UILayer punya method set_move_vector",
		ui.has_method("set_move_vector"))

	var joystick := _find_joystick(ui)
	_check("Node VirtualJoystick ada di scene UI", joystick != null)
	if joystick == null:
		return

	# Joystick harus bisa menemukan node UILayer di rantai parent-nya.
	var target: Node = joystick.call("_find_ui_layer")
	_check("Joystick menemukan UILayer di parent chain", target != null)
	_check("Target joystick punya set_move_vector",
		target != null and target.has_method("set_move_vector"))

	# Simulasikan drag ke kanan: vektor harus terbit di UILayer.move_vector.
	ui.call("set_move_vector", Vector2.ZERO)
	joystick.call("_update", Vector2(120.0, 0.0))
	var published: Vector2 = ui.get("move_vector")
	_check("Drag joystick mempublikasikan vektor",
		published.length() > 0.01,
		"(vektor %s)" % str(published))
	_check("Vektor bergerak ke kanan (x positif)", published.x > 0.0,
		"(vektor %s)" % str(published))

	# Lepas joystick -> vektor kembali nol.
	joystick.call("_release")
	var cleared: Vector2 = ui.get("move_vector")
	_check("Lepas joystick -> vektor kembali nol",
		cleared.length() < 0.001,
		"(vektor %s)" % str(cleared))


## Regresi bug build .exe: W berjalan mundur dan S berjalan maju.
##
## `Input.get_vector(move_left, move_right, move_forward, move_back)` memberi
## y = -1 untuk W dan y = +1 untuk S. Kamera pemain menghadap ke -Z, jadi
## W harus menghasilkan z negatif (maju menjauhi kamera).
func _test_movement_direction() -> void:
	var fwd: Vector3 = PLAYER_SCRIPT.input_to_world(Vector2(0.0, -1.0))
	_check("Tekan W -> pemain maju ke arah -Z", fwd.z < -0.9,
		"(arah %s)" % str(fwd))
	var back: Vector3 = PLAYER_SCRIPT.input_to_world(Vector2(0.0, 1.0))
	_check("Tekan S -> pemain mundur ke arah +Z", back.z > 0.9,
		"(arah %s)" % str(back))
	var right: Vector3 = PLAYER_SCRIPT.input_to_world(Vector2(1.0, 0.0))
	_check("Tekan D -> pemain bergerak ke +X", right.x > 0.9,
		"(arah %s)" % str(right))
	var left: Vector3 = PLAYER_SCRIPT.input_to_world(Vector2(-1.0, 0.0))
	_check("Tekan A -> pemain bergerak ke -X", left.x < -0.9,
		"(arah %s)" % str(left))

	# Joystick harus memakai konvensi yang sama dengan keyboard:
	# digeser ke atas (koordinat layar) -> y negatif -> maju (-Z).
	var ui := get_tree().root.get_node_or_null("UILayer")
	if ui != null:
		var joystick := _find_joystick(ui)
		if joystick != null:
			ui.call("set_move_vector", Vector2.ZERO)
			joystick.call("_update", Vector2(0.0, -120.0))
			var joy: Vector2 = ui.get("move_vector")
			_check("Joystick ke atas -> vektor y negatif", joy.y < -0.9,
				"(vektor %s)" % str(joy))
			var joy_fwd: Vector3 = PLAYER_SCRIPT.input_to_world(joy)
			_check("Joystick atas -> arah maju (-Z)", joy_fwd.z < -0.9,
				"(arah %s)" % str(joy_fwd))
			joystick.call("_release")


## Cari node VirtualJoystick di bawah scene UI milik autoload UILayer.
func _find_joystick(ui: Node) -> Node:
	var root := ui.get("_ui_root") as Node
	if root == null:
		return null
	return root.get_node_or_null("VirtualJoystick")


## Task 12 — SFX prosedural (autoload `Audio`, tanpa aset eksternal).
func _test_task12_sfx(loc_root: Node3D) -> void:
	var audio := get_tree().root.get_node_or_null("Audio")
	_check("Autoload Audio ada", audio != null)
	if audio == null:
		return

	# --- Daftar bunyi ---
	var ids: Array = audio.call("sfx_ids")
	_check("Ada 10 bunyi yang terdaftar", ids.size() == 10,
		"(dapat %d)" % ids.size())
	for required in [&"pour", &"stir", &"ice", &"cash", &"complain"]:
		_check("Bunyi '%s' terdaftar" % required, ids.has(required))

	# --- Setiap bunyi harus benar-benar menghasilkan stream audio ---
	for id in ids:
		var stream: AudioStreamWAV = audio.call("_stream_for", id)
		_check("Bunyi '%s' punya stream PCM" % id,
			stream != null and stream.data.size() > 0)
		if stream != null:
			_check("Bunyi '%s' format 16-bit" % id,
				stream.format == AudioStreamWAV.FORMAT_16_BITS)

	# --- Bunyi bisa dimainkan tanpa error ---
	for id in ids:
		audio.call("play", id)
	_check("Semua bunyi bisa dimainkan tanpa error", true)

	# --- Cache: stream yang sama dipakai ulang ---
	var s1: AudioStreamWAV = audio.call("_stream_for", &"pour")
	var s2: AudioStreamWAV = audio.call("_stream_for", &"pour")
	_check("Stream bunyi di-cache (objek sama)", s1 == s2)

	# --- Toggle enable / disable ---
	audio.call("set_enabled", false)
	_check("Audio bisa dimatikan", not audio.call("is_enabled"))
	audio.call("play", &"pour")
	audio.call("set_enabled", true)
	_check("Audio bisa dinyalakan lagi", audio.call("is_enabled"))

	# --- Pool player siap ---
	var pool: Array = audio.get("_pool")
	_check("Pool SFX punya 8 player", pool.size() == 8,
		"(dapat %d)" % pool.size())

	# --- Ambient music loop ---
	var ambient_player: AudioStreamPlayer = audio.get("_ambient_player")
	_check("Ambient music berjalan", ambient_player != null)
	if ambient_player != null:
		var ambient := ambient_player.stream as AudioStreamWAV
		_check("Ambient music loop", ambient != null
			and ambient.loop_mode == AudioStreamWAV.LOOP_FORWARD)

	# --- Hook ke kejadian game ---
	var stand := _find_stand(loc_root)
	if stand == null:
		return
	var prep := stand.prep_station
	var log: Array = audio.get("play_log")

	# --- Langkah prep -> bunyi ---
	log.clear()
	prep.open_build()
	prep.select_brand(Catalog.brands[0])
	prep.pour(0.8)
	prep.add_water()
	prep.stir()
	prep.add_ice(2)
	prep.add_straw()
	await get_tree().process_frame
	_check("Langkah prep memicu bunyi", log.size() >= 5,
		"(dapat %d: %s)" % [log.size(), log])
	_check("Bunyi 'pour' dipanggil saat menuang", log.has(&"pour"))
	_check("Bunyi 'water' dipanggil saat menambah air", log.has(&"water"))
	_check("Bunyi 'stir' dipanggil saat mengaduk", log.has(&"stir"))
	_check("Bunyi 'ice' dipanggil saat menambah es", log.has(&"ice"))
	_check("Bunyi 'straw' dipanggil saat menambah sedotan", log.has(&"straw"))

	# --- Bunyi 'build' saat tas jadi ---
	Inventory.add_sachets(Catalog.brands[0].id, 2)
	log.clear()
	var bag := prep.build_bag()
	_check("Tas berhasil dibuat untuk tes bunyi", bag != null)
	_check("Bunyi 'build' dipanggil saat tas jadi", log.has(&"build"))

	# --- Pelanggan yang mengeluh -> bunyi complain ---
	var customer_scene: PackedScene = load("res://src/entities/Customer.tscn")
	_check("Scene Customer bisa dimuat", customer_scene != null)
	var customer := customer_scene.instantiate() as Customer
	if customer != null:
		loc_root.add_child(customer)
		log.clear()
		customer.complain.emit("Lama amat, bang...", 0.6)
		_check("Bunyi 'complain' dipanggil saat pelanggan mengeluh",
			log.has(&"complain"))
		customer.queue_free()

	# --- Melayani pelanggan -> bunyi cash + serve ---
	var brand: SachetBrand = Catalog.brands[0]
	var c2 := customer_scene.instantiate() as Customer
	if c2 != null:
		loc_root.add_child(c2)
		c2.setup(brand, 1.0)
		c2.state = Customer.State.WAITING
		prep.open_build()
		prep.select_brand(brand)
		prep.pour(1.0)
		prep.add_water()
		prep.stir()
		prep.add_ice(2)
		prep.add_straw()
		var good_bag := prep.build_bag()
		if good_bag != null:
			stand.offer_bag(good_bag)
			log.clear()
			var result := stand.serve_offered_to(c2)
			_check("Es tanpa masalah diterima pelanggan",
				bool(result.get("accepted", false)),
				"(hasil %s)" % result)
			_check("Bunyi 'cash' dipanggil setelah pembayaran",
				log.has(&"cash"))
			_check("Bunyi 'serve' dipanggil saat menyerahkan es",
				log.has(&"serve"))
		c2.queue_free()


# --- Helpers -------------------------------------------------------------

func _find_stand(loc_root: Node3D) -> Stand:
	if loc_root == null:
		return null
	return loc_root.get_node_or_null("StandSlot/Stand") as Stand


## True bila node (atau turunannya) punya MeshInstance3D dengan mesh berisi
## permukaan sungguhan. Dipakai untuk memastikan propsi stand sudah pakai
## aset Kenney, bukan BoxMesh primitif.
func _has_mesh(node: Node) -> bool:
	if node == null:
		return false
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			return false
		return mi.mesh.get_surface_count() > 0
	for child in node.get_children():
		if _has_mesh(child):
			return true
	return false


func _fail(msg: String) -> void:
	_failures += 1
	print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("=== Selesai: %d/%d cek lolos, %d gagal ===" % [_checks - _failures, _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
