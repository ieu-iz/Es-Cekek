## LocationManager.gd
# Singleton. Plan §Architecture (LocationManager) + §World/Location Loading.
# Owns the list of reachable locations and swaps the active Location scene on demand.
# Locations load via loading screen (MVP: no seamless streaming — milestone 2).
extends Node

signal location_changed(new_location: LocationDef)
signal load_started
signal load_finished

var available_locations: Array[LocationDef] = []
var current_location: LocationDef = null
var current_root: Node3D = null   # root Node3D for the loaded Location in the world tree


# Set the full catalog of reachable locations (call once at game start).
func set_locations(locations: Array[LocationDef]) -> void:
	available_locations = locations.duplicate()


func unlock_location(id: StringName) -> void:
	if not has_location(id) and not available_locations.any(func(l): return l.id == id):
		# no-op unless unlocked later
		pass


func has_location(id: StringName) -> bool:
	return available_locations.any(func(l: LocationDef) -> bool: return l.id == id)


func get_location(id: StringName) -> LocationDef:
	for l in available_locations:
		if l.id == id:
			return l
	return null


# world_root: persistent Node3D under Main that holds the location scene.
# def: LocationDef whose .scene_path is loaded.
func load_location(world_root: Node3D, def: LocationDef) -> void:
	if world_root == null or def == null:
		push_error("LocationManager: invalid world_root or def")
		return

	load_started.emit()
	UILayer.show_loading(true, "Menghubungkan %s…" % def.display_name)

	# Free previous location (keep Player + UI singletons on Main).
	if current_root != null and is_instance_id_valid(current_root.get_instance_id()):
		current_root.queue_free()
		current_root = null

	if not ResourceLoader.exists(def.scene_path):
		push_error("LocationManager: scene missing %s — falling back to current location" % def.scene_path)
		UILayer.show_error("Lokasi gagal dimuat. Coba lagi.")
		UILayer.show_loading(false)
		load_finished.emit()
		return

	var scene := load(def.scene_path) as PackedScene
	if scene == null:
		UILayer.show_error("Scene Location tidak valid.")
		UILayer.show_loading(false)
		return

	var root := scene.instantiate() as Node3D
	if root == null:
		UILayer.show_error("Gagal memuat lokasi.")
		UILayer.show_loading(false)
		return

	world_root.add_child(root)
	current_root = root
	current_location = def

	# Let the Location scene initialize itself with this LocationDef.
	if root.has_method("initialize"):
		root.initialize(def)

	# Ensure Player is positioned at the stand spawn point.
	if root.has_method("stand_spawn_position"):
		var player = get_tree().get_nodes_in_group("player").front()
		if player != null and player is Node3D:
			player.global_transform.origin = root.stand_spawn_position()

	UILayer.show_loading(false)
	location_changed.emit(def)
	load_finished.emit()


func travel_to(id: StringName) -> void:
	var def := get_location(id)
	if def == null:
		return
	var world_root := _find_world_root()
	if world_root == null:
		return
	load_location(world_root, def)


func _find_world_root() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var roots := tree.get_nodes_in_group("world_root")
	if not roots.is_empty():
		return roots[0] as Node3D
	return null
