## KenneyCharacter.gd
# Karakter 3D dari asset **Kenney "Mini Characters"** (CC0, low-poly).
#
# Kenapa file ini ada:
#   Dulu Customer dan Player memakai BoxMesh/SphereMesh/CapsuleMesh primitif.
#   Sekarang keduanya memakai model GLB asli (12 varian) supaya dunia tidak
#   hanya kumpunan poligon.
#
# Fakta penting hasil inspeksi asset (lihat `context.md` § Kenney):
#   - tinggi model di file GLB = 0.6713 m  ->  skala 2.53 -> 1.7 m (manusia)
#   - model menghadap ke **+Z** di file GLB, sedangkan Godot memakai **-Z**
#     sebagai arah depan  ->  model di-yaw 180°
#   - animasi: `idle` (1.33 s), `walk` (0.67 s, jalan di tempat / in-place),
#     `sit`, `crouch`, `emote-no`, ...  (32 animasi)
#   - semua animasi datang dengan `loop_mode = 0` (linear)  ->  harus di-set
#     loop secara manual, kalau tidak karakter akan membeku di frame terakhir
#   - mesh `body-mesh` dan `head-mesh` memakai material yang SAMA, jadi
#     material harus di-duplikasi per mesh agar badan dan kepala bisa
#     di-warnai beda.
#
# Catatan: Bone `root` pada animasi `walk` hanya berisi gunungan vertikal
# (tidak ada translasi maju), jadi node tetap harus digerakkan manual oleh
# `Customer._walk_towards()`.
class_name KenneyCharacter
extends Node3D

## Semua varian karakter mini Kenney (6 perempuan + 6 laki-laki).
const MODELS: Array[PackedScene] = [
	preload("res://assets/kenney/mini/character-female-a.glb"),
	preload("res://assets/kenney/mini/character-female-b.glb"),
	preload("res://assets/kenney/mini/character-female-c.glb"),
	preload("res://assets/kenney/mini/character-female-d.glb"),
	preload("res://assets/kenney/mini/character-female-e.glb"),
	preload("res://assets/kenney/mini/character-female-f.glb"),
	preload("res://assets/kenney/mini/character-male-a.glb"),
	preload("res://assets/kenney/mini/character-male-b.glb"),
	preload("res://assets/kenney/mini/character-male-c.glb"),
	preload("res://assets/kenney/mini/character-male-d.glb"),
	preload("res://assets/kenney/mini/character-male-e.glb"),
	preload("res://assets/kenney/mini/character-male-f.glb"),
]

## Tinggi model = 0.6713 m. 0.6713 * 2.53 = 1.70 m (tinggi manusia).
const MODEL_SCALE: float = 2.53
## Model menghadap +Z; Godot memakai -Z sebagai arah depan.
const MODEL_YAW: float = PI

const ANIM_IDLE: StringName = &"idle"
const ANIM_WALK: StringName = &"walk"

## Nama node mesh di dalam file GLB.
const MESH_BODY: StringName = &"body-mesh"
const MESH_HEAD: StringName = &"head-mesh"

## Warna "marah" yang dikalikan ke albedo (bukan diganti) supaya tekstur
## colormap.png tetap terlihat.
const ANGRY_TINT: Color = Color(1.0, 0.45, 0.42)
const ANGRY_SKIN_TINT: Color = Color(1.0, 0.62, 0.62)
## Sudut badan condong ke depan saat kesal (derajat).
const ANGRY_LEAN_DEG: float = 8.0

## Index model yang dipakai. -1 = acak (dipakai untuk pelanggan).
@export var model_index: int = -1

var _model: Node3D = null
var _anim: AnimationPlayer = null
var _body_mesh: MeshInstance3D = null
var _head_mesh: MeshInstance3D = null
var _body_mat: StandardMaterial3D = null
var _head_mat: StandardMaterial3D = null
var _playing: StringName = &""


func _ready() -> void:
	_build()


## Bangun model karakter (sekali saja).
func _build() -> void:
	if _model != null:
		return
	var idx := model_index
	if idx < 0 or idx >= MODELS.size():
		idx = randi() % MODELS.size()
	var scene: PackedScene = MODELS[idx]
	_model = scene.instantiate() as Node3D
	if _model == null:
		push_warning("KenneyCharacter: model gagal di-instantiate.")
		return
	# GLB menghadap +Z, Godot memakai -Z -> putar 180 derajat.
	_model.rotation.y = MODEL_YAW
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)

	_anim = _find_anim(_model)
	_body_mesh = _find_mesh(_model, MESH_BODY)
	_head_mesh = _find_mesh(_model, MESH_HEAD)
	_duplicate_materials()
	_make_looping([ANIM_IDLE, ANIM_WALK])
	play(ANIM_IDLE)


## Material asli GLB dipakai bersama oleh body-mesh dan head-mesh, jadi
## setiap mesh dapat salinannya sendiri supaya bisa di-warnai terpisah.
## `duplicate()` dipakai tanpa flag sub-resource supaya tekstur colormap.png
## tetap dipakai (bukan di-copy), hemat memori.
func _duplicate_materials() -> void:
	_body_mat = _make_unique_material(_body_mesh)
	_head_mat = _make_unique_material(_head_mesh)


func _make_unique_material(mesh_node: MeshInstance3D) -> StandardMaterial3D:
	if mesh_node == null or mesh_node.mesh == null:
		return null
	var src := mesh_node.get_active_material(0) as StandardMaterial3D
	if src == null:
		return null
	var copy := src.duplicate() as StandardMaterial3D
	if copy == null:
		return null
	mesh_node.material_override = copy
	return copy


## Animasi Kenney datang dengan loop_mode linear -> set loop supaya tidak
## berhenti di frame terakhir.
func _make_looping(names: Array[StringName]) -> void:
	if _anim == null:
		return
	for n in names:
		if not _anim.has_animation(n):
			continue
		var anim := _anim.get_animation(n)
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR


## Mainkan animasi (kalau belum sedang mainframe yang sama).
func play(anim_name: StringName) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _playing == anim_name and _anim.is_playing():
		return
	_anim.play(anim_name)
	_playing = anim_name


## Idle vs jalan. Dipakai Customer saat datang / pulang.
func set_moving(moving: bool) -> void:
	if moving:
		play(ANIM_WALK)
	else:
		play(ANIM_IDLE)


## 0..1 tingkat kesal: badan makin merah + badan condong ke depan.
func set_annoyance(amount: float) -> void:
	var c := clampf(amount, 0.0, 1.0)
	if _body_mat != null:
		_body_mat.albedo_color = Color.WHITE.lerp(ANGRY_TINT, c * 0.85)
	if _head_mat != null:
		_head_mat.albedo_color = Color.WHITE.lerp(ANGRY_SKIN_TINT, c * 0.5)
	if _model != null:
		_model.rotation.x = deg_to_rad(-ANGRY_LEAN_DEG * c)


## Node model (dipakai kalau butuh transform khusus).
func model() -> Node3D:
	return _model


func _find_anim(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node.get_class() == "AnimationPlayer":
		return node as AnimationPlayer
	for c in node.get_children():
		var found := _find_anim(c)
		if found != null:
			return found
	return null


func _find_mesh(node: Node, mesh_name: StringName) -> MeshInstance3D:
	if node == null:
		return null
	if node.get_class() == "MeshInstance3D" and node.name == mesh_name:
		return node as MeshInstance3D
	for c in node.get_children():
		var found := _find_mesh(c, mesh_name)
		if found != null:
			return found
	return null
