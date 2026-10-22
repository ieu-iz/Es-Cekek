## Hand.gd
# Task 15 — first-person hands.
#
# Tangan virtual pemain (kiri & kanan). Satu tangan hanya boleh memegang satu
# objek. Aturan memilih tangan (sesuai permintaan player):
#   - objek yang paling dekat dengan tangan itu yang mengambil,
#   - kalau tangan itu sedang penuh, tangan lain yang free yang mengambil,
#   - `Q` (swap_hand) memaksa pengambilan berikutnya ke tangan yang lain.
class_name Hand
extends Node3D

## Catatan: enum bernama "Side"bentrok dengan tipe global Godot ("Side"),
## jadi dipakai "HandSide" supaya tidak ambigu.
enum HandSide { LEFT, RIGHT }

@export var side: HandSide = HandSide.LEFT
## Jangkauan tangan saat mencari objek terdekat (meter).
@export var reach_radius: float = 0.45
## Offset genggaman relatif terhadap node tangan.
@export var grip_offset: Vector3 = Vector3(0.0, -0.05, -0.16)

## Objek yang sedang dipegang (null = tangan kosong).
var holds: PrepObject = null


func _ready() -> void:
	# Node tangan harus bisa diputar/bergeser tanpa disturbing transform
	# parent, jadi transform lokal dipakai, bukan global.
	pass


## Tangan ini kosong?
func is_free() -> bool:
	return holds == null


## Nama tangan untuk pesan ("kiri" / "kanan").
func side_name() -> String:
	return "kiri" if side == HandSide.LEFT else "kanan"


## Ambil objek. Gagal kalau tangan sudah penuh atau objek sudah dipegang
## tangan lain.
func grab(obj: PrepObject) -> bool:
	if obj == null or holds != null or obj.held_by != null:
		return false
	if not obj.can_be_held():
		return false
	holds = obj
	obj.held_by = self
	var s := obj.scale
	obj.reparent(self, true)
	obj.transform = Transform3D(Basis().scaled(s), grip_offset)
	return true


## Lepas objek tanpa menaruhnya (dipakai kalau objek dibuang).
func release() -> PrepObject:
	var obj := holds
	holds = null
	if obj == null:
		return null
	obj.held_by = null
	return obj


## Lepas objek dan taruh di posisi dunia tertentu (mis. di atas meja).
func release_at(world_position: Vector3, yaw: float = 0.0) -> PrepObject:
	var obj := release()
	if obj == null:
		return null
	if obj.home_parent != null and is_instance_valid(obj.home_parent):
		obj.reparent(obj.home_parent, true)
		obj.global_position = world_position
		obj.rotation.y = yaw
		obj.scale = obj.home_transform.basis.get_scale()
	else:
		# Parent asal sudah hilang (lokasi diganti) — biarkan objek ikut tangan.
		obj.transform = Transform3D(Basis(), grip_offset)
	return obj


## Posisi genggaman di dunia (tempat ujung jari).
func grip_position() -> Vector3:
	if holds != null:
		return holds.global_position
	return global_position + (global_basis * grip_offset)
