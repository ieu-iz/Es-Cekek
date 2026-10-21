## Location.gd
# Runtime script for every Location scene. Plan §World/Location Loading.
# LocationManager instantiates the scene, then calls initialize(def) so the
# location can apply its palette and spawn data.
extends Node3D

## Extra offset from the stand slot so the player does not spawn inside the counter.
@export var spawn_offset: Vector3 = Vector3(0.0, 0.1, 2.6)

var location_def: LocationDef = null

@onready var stand_slot: Node3D = $StandSlot
@onready var customer_spawner: Node3D = $CustomerSpawner
@onready var props: Node3D = $Props


func initialize(def: LocationDef) -> void:
	location_def = def
	_apply_palette()
	_apply_props()


## World position where the player should stand when arriving here.
func stand_spawn_position() -> Vector3:
	if stand_slot != null:
		return stand_slot.global_position + spawn_offset
	return global_position + Vector3(0.0, 0.1, 4.0)


func _apply_palette() -> void:
	if location_def == null:
		return
	var palette: Dictionary = location_def.color_palette
	var accent: Color = palette.get("accent", Color(0.8, 0.4, 0.3))

	var ground := get_node_or_null("Ground/GroundMesh") as MeshInstance3D
	if ground != null and palette.has("ground"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = palette["ground"]
		mat.roughness = 0.95
		ground.material_override = mat

	# The world sky + sun are owned by Main.tscn (persistent across loads).
	# Tint the sun per location so the three maps read differently.
	var sun := get_tree().get_first_node_in_group("sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = accent.lerp(Color(1, 1, 1), 0.6)


func _apply_props() -> void:
	# Per-location props are plain MeshInstance3D children of Props. The
	# location palette decides their tint so the three maps read differently.
	if location_def == null or props == null:
		return
	var accent: Color = location_def.color_palette.get("accent", Color(0.8, 0.4, 0.3))
	for child in props.get_children():
		var mesh_node := child as MeshInstance3D
		if mesh_node == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = accent
		mat.roughness = 0.85
		mesh_node.material_override = mat
