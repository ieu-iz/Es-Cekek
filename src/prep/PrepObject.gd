## PrepObject.gd
# Task 15 — first-person hands.
#
# Semua alat & bahan untuk membuat es cekek ada sebagai objek 3D di meja
# konter. Tangan kiri/kanan pemain bisa mengambil, memindahkan, dan
# meletakkannya kembali. Kombinasi dua objek (mis. gunting + sachet) memicu
# langkah resep — lihat `RecipeRules.gd`.
#
# State fisik objek (dipotong, ada serbuk, ada air, ...) disimpan DI SINI,
# bukan di sesi prep, supaya apa yang terlihat di meja selalu sama dengan
# apa yang sudah dilakukan.
class_name PrepObject
extends Node3D

## Jenis objek. `RecipeRules` memakai ini untuk menentukan aturan interaksi.
enum Kind {
	SACHET,       # sachet serbub (satu per brand)
	SCISSORS,     # gunting pemotong sachet
	PLASTIC_BAG,  # plastik (wadah pembuatan)
	WATER_JUG,    # jerigen air
	ICE_COOLER,   # cooler es
	ICE_SCOOP,    # serok es
	SPOON,        # sendok aduk
	STRAW,        # sedotan
}

## Bit layer khusus picking (bit ke-2). Ray pick hanya memindai layer ini
## supaya tidak pernah menabrak area interaksi pemain atau body lain.
const PICK_LAYER: int = 2

## Nama grup untuk mencari semua objek yang bisa dipegang.
const GROUP: StringName = &"prep_object"

## Nama node anak mesh.
const MESH_NODE: String = "Mesh"

@export var kind: Kind = Kind.SACHET
@export var display_name: String = "Objek"
## Ukuran kotak picking (meter, dalam ruang lokal objek).
@export var pick_size: Vector3 = Vector3(0.16, 0.10, 0.12)

## Brand untuk sachet (null untuk objek lain).
var brand: SachetBrand = null
## Tangan yang sedang memegang objek ini (null = objek berada di meja).
var held_by: Hand = null
## Parent asal + transform lokal asal, dipakai untuk mengembalikan objek.
## Node3D (bukan Node) supaya `to_global()` punya tipe yang jelas.
var home_parent: Node3D = null
var home_transform: Transform3D = Transform3D.IDENTITY

# --- State fisik objek -------------------------------------------------

## Sachet sudah dipotong gunting?
var is_cut: bool = false
## Plastik sudah berisi serbub sachet?
var has_powder: bool = false
## Level air di plastik (0..1).
var water_level: float = 0.0
## Plastik sudah diaduk?
var is_stirred: bool = false
## Sendok es yang sudah masuk ke plastik.
var ice_spoons: int = 0
## Plastik sudah ada sedotan?
var has_straw: bool = false
## Es yang dipegang serok (0 = serok kosong).
var scoop_ice: int = 0
## Sachet sudah dikosongkan (serbunya sudah pindah ke plastik).
var is_emptied: bool = false

## Area picking (dibuat otomatis kalau scene tidak menyediakannya).
var _pick_area: Area3D = null
## Mesh objek (dipakai untuk pewarna brand).
var _mesh: MeshInstance3D = null


func _ready() -> void:
	add_to_group(GROUP)
	home_parent = get_parent() as Node3D
	home_transform = transform
	_mesh = _find_mesh()
	_pick_area = get_node_or_null("PickArea") as Area3D
	if _pick_area == null:
		_pick_area = _create_pick_area()
	apply_brand_tint()


## Cari mesh objek: node anak bernama "Mesh" (MeshInstance3D), atau mesh
## pertama di dalam instance GLB.
func _find_mesh() -> MeshInstance3D:
	var direct := get_node_or_null(MESH_NODE) as MeshInstance3D
	if direct != null:
		return direct
	return _find_mesh_recursive(self)


func _find_mesh_recursive(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
		var found := _find_mesh_recursive(child)
		if found != null:
			return found
	return null


## Buat area picking kotak sesuai ukuran objek. Area ini SATU-SATUNYA yang
## boleh ditembak ray pick, jadi tidak akan pernah tertabrak mesh lain.
func _create_pick_area() -> Area3D:
	var area := Area3D.new()
	area.name = "PickArea"
	area.collision_layer = PICK_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = pick_size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	return area


## Warna mesh mengikuti brand (dipakai sachet). Material ASLI dari GLB itu
## shared antar-instance, jadi harus diduplikasi dulu (Gotcha #18) supaya
## satu sachet tidak ikut berubah warnanya.
func apply_brand_tint() -> void:
	if brand == null or _mesh == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = brand.color_tint
	mat.roughness = 0.55
	var surfaces := _mesh.mesh.get_surface_count() if _mesh.mesh != null else 0
	if surfaces == 0:
		_mesh.material_override = mat
		return
	for i in range(surfaces):
		var src := _mesh.get_surface_override_material(i)
		if src == null and _mesh.mesh != null:
			src = _mesh.mesh.surface_get_material(i)
		var dup := mat.duplicate() as StandardMaterial3D
		if src is StandardMaterial3D:
			# Pertahankan tekstur asli, hanya ganti warnanya.
			dup = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.albedo_color = brand.color_tint
		_mesh.set_surface_override_material(i, dup)


## Apakah objek ini wadah pembuatan (plastik)?
func is_vessel() -> bool:
	return kind == Kind.PLASTIC_BAG


## Apakah objek ini bisa dipegang tangan?
func can_be_held() -> bool:
	return true


## Kosongkan isi objek (dipakai setelah es diserahkan ke pelanggan).
func reset_contents() -> void:
	is_cut = false
	has_powder = false
	water_level = 0.0
	is_stirred = false
	ice_spoons = 0
	has_straw = false
	scoop_ice = 0
	is_emptied = false


## Kembalikan objek ke posisi semula di meja.
func return_home() -> void:
	if home_parent == null or not is_instance_valid(home_parent):
		return
	if get_parent() != home_parent:
		reparent(home_parent, true)
	transform = home_transform


## Label pendek untuk HUD.
func short_label() -> String:
	if kind == Kind.SACHET and brand != null:
		return brand.display_name
	return display_name
