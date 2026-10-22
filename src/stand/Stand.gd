## Stand.gd
# Plan §Architecture (Stand) + Task 6/7: the player's stand.
# Owns the counter, the StandEquipment (tool slots), the PrepStation, the seat
# markers and the queue markers, and mediates the serve transaction.
#
# The stand is the hub of the prep/serve loop:
#   Player -> Stand -> PrepStation -> Bag -> Customer -> Inventory
class_name Stand
extends Node3D

signal served(result: Dictionary)
signal bag_offered(bag: Bag)
signal prep_changed

@onready var equipment: StandEquipment = $StandEquipment
@onready var prep_station: PrepStation = $PrepStation
@onready var counter: Node3D = $Counter
@onready var seats_root: Node3D = $Seats
@onready var queue_root: Node3D = $Queue
## Visual tas 3D di meja (Task 12).
@onready var bag_visual: Node3D = $BagVisual
@onready var bag_shell: MeshInstance3D = $BagVisual/Shell
@onready var bag_liquid: MeshInstance3D = $BagVisual/Liquid
@onready var bag_straw: MeshInstance3D = $BagVisual/Straw

## Batas prep_quality: di bawah nilai ini tas di meja terlihat "keruh".
const BAG_QUALITY_GOOD: int = 60

## The bag currently being offered to a customer (built, not yet served).
## Setiap perubahan nilai langsung memperbarui tas 3D di meja, jadi tidak
## ada cara untuk menyisakan tas basi di counter.
var current_bag: Bag = null:
	set(value):
		current_bag = value
		_refresh_bag_visual()
## The spawner that fills this stand's seats and queue.
var spawner: CustomerSpawner = null
## Harga yang dipilih pemain untuk es yang sedang dibuat (Task 15).
## Berlaku juga SEBELUM tas dibuat, supaya harga bisa diatur lebih dulu.
var target_price: float = 0.0


func _ready() -> void:
	prep_station.set_equipment(equipment)
	prep_station.set_rack(Catalog.brands)
	equipment.refresh_from_inventory()

	# Sachet fisik di meja <- brand dari katalog (Task 15).
	_setup_sachets()

	# Keep the stand's slots in sync when the player buys a new tool.
	var cb := _on_tools_changed
	if not Inventory.tools_changed.is_connected(cb):
		Inventory.tools_changed.connect(cb)

	# Forward prep actions from the UI to the PrepStation.
	var on_action := _on_prep_action
	if not UILayer.prep_action.is_connected(on_action):
		UILayer.prep_action.connect(on_action)

	# SFX prosedural (Task 12) — tiap langkah pembuatan es punya bunyi.
	_wire_sfx()

	# Refresh the prep panel whenever the prep state changes.
	prep_station.prep_changed.connect(_refresh_ui)

	# Visual tas 3D di meja (Task 12).
	_setup_bag_materials()
	_refresh_bag_visual()


func set_spawner(customer_spawner: CustomerSpawner) -> void:
	spawner = customer_spawner


## Pasang brand ke sachet fisik di meja (urutan kiri -> kanan = urutan
## katalog) dan warnai sesuai brand masing-masing.
func _setup_sachets() -> void:
	var sachets: Array[PrepObject] = []
	for child in prep_station.get_children():
		var obj := child as PrepObject
		if obj != null and int(obj.kind) == PrepObject.Kind.SACHET:
			sachets.append(obj)
	for i in range(sachets.size()):
		if i >= Catalog.brands.size():
			break
		var brand := Catalog.brands[i]
		sachets[i].brand = brand
		sachets[i].display_name = brand.display_name
		sachets[i].apply_brand_tint()


## Hubungkan sinyal langkah prep ke bunyi prosedural (autoload `Audio`).
func _wire_sfx() -> void:
	_connect_sfx(prep_station.pour_done, &"pour")
	_connect_sfx(prep_station.water_added, &"water")
	_connect_sfx(prep_station.stirred, &"stir")
	_connect_sfx(prep_station.ice_added, &"ice")
	_connect_sfx(prep_station.straw_added, &"straw")
	# `bag_built` membawa argumen Bag, jadi punya handler sendiri.
	if not prep_station.bag_built.is_connected(_on_bag_built):
		prep_station.bag_built.connect(_on_bag_built)


## Hubungkan satu sinyal tanpa argumen ke bunyi tertentu (idempoten).
func _connect_sfx(sig: Signal, sfx_id: StringName) -> void:
	var cb := _on_prep_sfx.bind(sfx_id)
	if not sig.is_connected(cb):
		sig.connect(cb)


## Handler tunggal untuk semua sinyal langkah prep -> bunyi.
func _on_prep_sfx(sfx_id: StringName) -> void:
	Audio.play(sfx_id)


## Bunyi "build" — tas selesai dibuat.
func _on_bag_built(_bag: Bag) -> void:
	Audio.play(&"build")


func _on_tools_changed() -> void:
	equipment.refresh_from_inventory()


# --- Layout -------------------------------------------------------------

## World positions of the seat markers, in order.
func seat_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if seats_root == null:
		return out
	for child in seats_root.get_children():
		var n := child as Node3D
		if n != null:
			out.append(n.global_position)
	return out


## World positions of the queue markers, in order.
func queue_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if queue_root == null:
		return out
	for child in queue_root.get_children():
		var n := child as Node3D
		if n != null:
			out.append(n.global_position)
	return out


## Where the player stands to work at the counter.
func service_position() -> Vector3:
	if counter != null:
		return counter.global_position + Vector3(0.0, 0.0, 1.6)
	return global_position + Vector3(0.0, 0.0, 1.6)


## Titik di sisi pelanggan tempat pelanggan berdiri untuk mengambil es.
func pickup_position() -> Vector3:
	if counter != null:
		return counter.global_position + Vector3(0.0, 0.0, 0.95)
	return global_position + Vector3(0.0, 0.0, 0.95)


# --- Bag / serve --------------------------------------------------------

## Put a freshly built bag on the counter, ready to be served.
func offer_bag(bag: Bag) -> void:
	if bag != null and target_price > 0.0:
		# Harga yang sudah dipilih pemain dipakai untuk tas ini.
		bag.sell_price = maxf(target_price, bag.cost())
	current_bag = bag
	if bag != null:
		bag_offered.emit(bag)


## Take the offered bag off the counter (it is now consumed by the serve).
func take_bag() -> Bag:
	var bag := current_bag
	current_bag = null
	return bag


## Serve `bag` to `customer`. Handles the refuse path (wrong brand => no pay,
## bag wasted, customer annoyance +0.2) and the happy path (money + tip).
func serve_to(customer: Customer, bag: Bag) -> Dictionary:
	if customer == null or bag == null:
		return {"ok": false, "accepted": false, "line": "Tidak ada yang bisa dilayani."}
	if customer.order_brand == null:
		return {"ok": false, "accepted": false, "line": "Pelanggan tidak punya pesanan."}

	var result := customer.evaluate_serve(bag)

	if bool(result.get("accepted", false)):
		var paid := float(result.get("total_paid", 0.0))
		Inventory.add_money(paid)
		var loc_id: StringName = &""
		if LocationManager.current_location != null:
			loc_id = LocationManager.current_location.id
		Economy.record_sale(customer.order_brand.id, loc_id, paid)
		# Bunyi uang diterima (Task 12).
		Audio.play(&"cash")
	# Catatan: bunyi "complain" ikut keluar dari sinyal `Customer.complain`,
	# jadi jalur menolak (salah brand / kemahalan) sudah tercakup di sana.

	served.emit(result)
	return result


## Serve the offered bag to a specific customer, if there is one.
func serve_offered_to(customer: Customer) -> Dictionary:
	if current_bag == null:
		return {"ok": false, "accepted": false, "line": "Belum ada es yang dibuat."}
	var bag := take_bag()
	Audio.play(&"serve")
	return serve_to(customer, bag)


## Snapshot for the UI (prep state + price bounds of the offered bag).
func snapshot() -> Dictionary:
	var data := prep_station.snapshot()
	data["has_bag"] = current_bag != null
	data["stock_sachet"] = _stock_of(prep_station.selected_brand)
	data["stock_ice"] = Inventory.ice_stock
	if current_bag != null:
		data["price"] = current_bag.sell_price
		data["cost"] = current_bag.cost()
		data["fair_min"] = current_bag.fair_price_min()
		data["fair_max"] = current_bag.fair_price_max()
		data["recommended"] = current_bag.recommended_price()
		data["quality"] = current_bag.prep_quality
	else:
		# Belum ada tas: harga tetap bisa diatur untuk es yang sedang dibuat.
		var est := prep_station.estimated_cost()
		data["cost"] = est
		data["fair_min"] = est
		data["fair_max"] = est * 1.6
		data["recommended"] = est * 1.3
		data["price"] = target_price if target_price > 0.0 else est * 1.3
	return data


# --- Visual tas 3D di meja -----------------------------------------------

## Siapkan material tas. Material dibuat di runtime, bukan sub-resource di
## .tscn, supaya tiap stand punya material sendiri (sub-resource di .tscn
## dipakai bersama antar instance).
func _setup_bag_materials() -> void:
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color(0.92, 0.95, 0.97, 0.32)
	shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.roughness = 0.12
	_set_bag_material(bag_shell, shell)

	var liquid := StandardMaterial3D.new()
	liquid.roughness = 0.25
	_set_bag_material(bag_liquid, liquid)

	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.95, 0.32, 0.40)
	straw.roughness = 0.4
	_set_bag_material(bag_straw, straw)


func _set_bag_material(mesh: MeshInstance3D, mat: Material) -> void:
	if mesh == null:
		return
	mesh.material_override = mat


## Perbarui tas 3D di meja:
##   - warna liquid mengikuti brand,
##   - tinggi liquid mengikuti volume,
##   - es batu membuat warna makin pucat,
##   - kualitas rendah membuat tas terlihat keruh.
func _refresh_bag_visual() -> void:
	if bag_visual == null:
		return
	if current_bag == null:
		bag_visual.visible = false
		return
	bag_visual.visible = true

	var brand := current_bag.primary_brand()
	var tint := Color(0.85, 0.85, 0.90)
	if brand != null:
		tint = brand.color_tint

	# Kualitas rendah -> warna pudar. Semakin rendah, semakin pudar.
	var quality_gap := clampf(
		(float(BAG_QUALITY_GOOD) - float(current_bag.prep_quality)) / float(BAG_QUALITY_GOOD),
		0.0, 1.0
	)
	if quality_gap > 0.0:
		tint = tint.lerp(Color(0.72, 0.70, 0.66), quality_gap * 0.6)

	# Es batu -> makin banyak, makin pucat ke arah putih.
	if current_bag.ice_amount > 0:
		var ice_ratio := clampf(
			float(current_bag.ice_amount) / float(Bag.MAX_SPOON_ICE), 0.0, 1.0
		)
		tint = tint.lerp(Color(0.93, 0.97, 1.0), ice_ratio * 0.35)

	var mat := bag_liquid.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = tint

	# Volume menentukan tinggi liquid di dalam tas.
	var volume := 1.0
	if current_bag.portions.size() > 0:
		volume = current_bag.portions[0].volume
	var height := clampf(0.35 + 0.65 * volume, 0.3, 1.0)
	bag_liquid.scale = Vector3(1.0, height, 1.0)
	# Liquid duduk di dasar tas (dasar tas = -0.15 dari titik tengah tas).
	bag_liquid.position = Vector3(0.0, -0.15 + 0.12 * height, 0.0)

	bag_straw.visible = current_bag.has_straw


# --- Player interaction -------------------------------------------------

## Called by the Player when it taps INTERACT at the stand.
## Task 15: bukan membuka panel 2D, tapi masuk mode first-person (tangan).
func interact_at_stand() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("enter_prep_mode"):
			p.call("enter_prep_mode", self)
			return
	# Tidak ada pemain (mis. tes): tetap siapkan sesi + tampilkan HUD.
	enter_prep()


## Dipanggil pemain saat masuk mode prep.
func enter_prep() -> void:
	prep_station.open_build()
	UILayer.show_prep_panel(true)
	_refresh_ui()


## Dipanggil pemain saat keluar dari mode prep.
func exit_prep() -> void:
	UILayer.show_prep_panel(false)
	prep_station.reset()
	_refresh_ui()


## Close the prep panel and release the player.
func close_prep() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("exit_prep_mode"):
			p.call("exit_prep_mode")
			return
	exit_prep()


# --- Prep panel actions -------------------------------------------------

func _refresh_ui() -> void:
	prep_changed.emit()
	if UILayer.is_prep_panel_open():
		UILayer.update_prep(snapshot())


## Hanya harga, restock, dan keluar yang tersisa sebagai tombol UI.
## Semua langkah pembuatan es dilakukan FISIK (lihat `RecipeRules`).
func _on_prep_action(action: StringName, value: float) -> void:
	match action:
		UILayer.ACTION_PRICE_INC:
			_adjust_price(UILayer.PRICE_STEP)
		UILayer.ACTION_PRICE_DEC:
			_adjust_price(-UILayer.PRICE_STEP)
		UILayer.ACTION_PRICE_SET:
			_set_price(value)
		UILayer.ACTION_RESTOCK_SACHET:
			_restock_sachet()
			_refresh_ui()
		UILayer.ACTION_RESTOCK_ICE:
			_restock_ice()
			_refresh_ui()
		UILayer.ACTION_SERVE:
			_serve_ready()
		UILayer.ACTION_CANCEL:
			close_prep()


## Serahkan es yang sudah jadi ke pelanggan terdekat. Diteruskan ke
## `PrepController` milik pemain yang sedang di mode prep.
func _serve_ready() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		var ctrl := p.get_node_or_null("PrepController") as PrepController
		if ctrl != null and ctrl.active:
			ctrl.deliver_to_nearest_customer()
			return
	UILayer.show_error("Tidak bisa落ち着いて: mode prep tidak aktif.")


## How many sachets of `brand` are in stock (0 when no brand is selected).
func _stock_of(brand: SachetBrand) -> int:
	if brand == null:
		return 0
	return Inventory.sachet_stock.get(brand.id, 0) as int


## Buy one sachet of the selected brand.
func _restock_sachet() -> void:
	var brand := prep_station.selected_brand
	if brand == null:
		UILayer.show_error("Pilih brand dulu sebelum restock.")
		return
	var bought := Inventory.restock_sachets(brand, 1)
	if bought == 0:
		UILayer.show_error("Uang tidak cukup untuk beli sachet.")
	else:
		UILayer.show_order("Beli %s 1 pcs" % brand.display_name)


## Buy a block of ice (10 spoons).
func _restock_ice() -> void:
	var bought := Inventory.restock_ice(10)
	if bought == 0:
		UILayer.show_error("Uang tidak cukup untuk beli es.")
	else:
		UILayer.show_order("Beli es %d sendok" % bought)


## Nudge the price of the offered bag. The price may never drop below cost.
func _adjust_price(delta: float) -> void:
	if current_bag != null:
		var cost := current_bag.cost()
		current_bag.sell_price = maxf(current_bag.sell_price + delta, cost)
		target_price = current_bag.sell_price
	else:
		var base := target_price if target_price > 0.0 else prep_station.estimated_cost() * 1.3
		target_price = maxf(base + delta, prep_station.estimated_cost())
	_refresh_ui()


## Set the price of the offered bag directly (the desktop price slider). The
## price may never drop below the cost of the ingredients.
func _set_price(value: float) -> void:
	if current_bag != null:
		current_bag.sell_price = maxf(value, current_bag.cost())
		target_price = current_bag.sell_price
	else:
		target_price = maxf(value, prep_station.estimated_cost())
	_refresh_ui()


func _do_serve() -> void:
	if spawner == null:
		UILayer.show_error("Tidak ada spawned pelanggan.")
		return
	var customer := spawner.next_customer()
	if customer == null:
		UILayer.show_error("Tidak ada pelanggan yang menunggu.")
		return
	var result := serve_offered_to(customer)
	if bool(result.get("accepted", false)):
		UILayer.show_order(Customer.THANK_YOU_LINE)
		customer.leave(global_position + Vector3(0.0, 0.0, 12.0))
		spawner.forget(customer)
	else:
		UILayer.show_complain(str(result.get("line", "Gagal melayani.")), customer.annoyance_level)
	_refresh_ui()
