## RecipeRules.gd
# Task 15 — first-person hands.
#
# Aturan fisika pembuatan es cekek. Setiap aturan berubah dari "dua objek
# berdekatan" menjadi "langkah resep". Resepnya (WAJIB berurutan):
#
#   1. gunting memotong sachet
#   2. serbub sachet masuk ke plastik
#   3. air dituang ke plastik
#   4. plastik diaduk
#   5. es diambil dengan serok lalu masuk ke plastik
#   6. sedotan dipasang
#
# Target suatu objek boleh dipegang tangan LAIN atau masih tergeletak di
# meja — jadi Rules cukup memeriksa jarak, bukan siapa yang memegang.
class_name RecipeRules
extends RefCounted

## Jarak maksimum dua objek untuk memicu interaksi (meter).
const INTERACT_DIST: float = 0.28

## Berapa banyak es (sendok) per satu serok.
const SCOOP_SPOONS: int = 2


## Cari langkah yang bisa dipicu oleh kondisi kedua tangan saat ini.
## Mengembalikan Dictionary kosong kalau tidak ada yang cocok, atau:
##   { "step": StringName, "actor": PrepObject, "target": PrepObject }
static func evaluate(left: Hand, right: Hand) -> Dictionary:
	var actors: Array[PrepObject] = []
	if left != null and left.holds != null:
		actors.append(left.holds)
	if right != null and right.holds != null:
		actors.append(right.holds)

	for actor in actors:
		var other := _other_hand_object(actor, left, right)

		# 1. Gunting + sachet -> sachet dipotong.
		if int(actor.kind) == PrepObject.Kind.SCISSORS:
			var t := _resolve_target(actor, other, PrepObject.Kind.SACHET)
			if t != null and not t.is_cut:
				return {"step": &"cut", "actor": actor, "target": t}

		# 2. Sachet terpotong + plastik -> serbub masuk plastik.
		if int(actor.kind) == PrepObject.Kind.SACHET and actor.is_cut:
			var t2 := _resolve_target(actor, other, PrepObject.Kind.PLASTIC_BAG)
			if t2 != null and not t2.has_powder:
				return {"step": &"pour_powder", "actor": actor, "target": t2}

		# 3. Jerigen air + plastik (sudah ada serbub) -> air masuk.
		if int(actor.kind) == PrepObject.Kind.WATER_JUG:
			var t3 := _resolve_target(actor, other, PrepObject.Kind.PLASTIC_BAG)
			if t3 != null and t3.has_powder and t3.water_level <= 0.0:
				return {"step": &"pour_water", "actor": actor, "target": t3}

		# 4. Sendok + plastik (sudah ada air) -> diaduk.
		if int(actor.kind) == PrepObject.Kind.SPOON:
			var t4 := _resolve_target(actor, other, PrepObject.Kind.PLASTIC_BAG)
			if t4 != null and t4.has_powder and t4.water_level > 0.0 and not t4.is_stirred:
				return {"step": &"stir", "actor": actor, "target": t4}

		# 5a. Serok + cooler -> serok terisi es.
		if int(actor.kind) == PrepObject.Kind.ICE_SCOOP and actor.scoop_ice <= 0:
			var t5 := _resolve_target(actor, other, PrepObject.Kind.ICE_COOLER)
			if t5 != null:
				return {"step": &"fill_scoop", "actor": actor, "target": t5}

		# 5b. Serok berisi es + plastik -> es masuk plastik.
		if int(actor.kind) == PrepObject.Kind.ICE_SCOOP and actor.scoop_ice > 0:
			var t6 := _resolve_target(actor, other, PrepObject.Kind.PLASTIC_BAG)
			if t6 != null and t6.has_powder:
				return {"step": &"add_ice", "actor": actor, "target": t6}

		# 6. Sedotan + plastik -> sedotan dipasang.
		if int(actor.kind) == PrepObject.Kind.STRAW:
			var t7 := _resolve_target(actor, other, PrepObject.Kind.PLASTIC_BAG)
			if t7 != null and not t7.has_straw:
				return {"step": &"add_straw", "actor": actor, "target": t7}

	return {}


## Terapkan langkah yang terpicu: ubah state objek + catat di sesi prep.
## Mengembalikan true kalau langkahnya benar-benar berubah.
static func apply_step(session: PrepStation, result: Dictionary) -> bool:
	if session == null or result.is_empty():
		return false
	var step: StringName = result.get("step", &"")
	var actor := result.get("actor") as PrepObject
	var target := result.get("target") as PrepObject
	if actor == null or target == null:
		return false

	match step:
		&"cut":
			target.is_cut = true
			if target.brand != null:
				session.select_brand(target.brand)
			session.record_step(&"cut")
			# Bunyi gunting: pakai efek "pour" (bunyi noise pendek).
			Audio.play(&"pour")
			return true
		&"pour_powder":
			session.pour(PrepStation.MAX_VOLUME)
			target.has_powder = true
			actor.is_emptied = true
			session.record_step(&"pour_powder")
			return true
		&"pour_water":
			session.add_water()
			target.water_level = 1.0
			session.record_step(&"pour_water")
			return true
		&"stir":
			session.stir()
			target.is_stirred = true
			session.record_step(&"stir")
			return true
		&"fill_scoop":
			actor.scoop_ice = SCOOP_SPOONS
			Audio.play(&"ice")
			return true
		&"add_ice":
			session.add_ice(actor.scoop_ice)
			target.ice_spoons += actor.scoop_ice
			actor.scoop_ice = 0
			session.record_step(&"add_ice")
			return true
		&"add_straw":
			session.add_straw()
			target.has_straw = true
			session.record_step(&"add_straw")
			return true
	return false


## Objek yang dipegang tangan lain (bukan `actor`).
static func _other_hand_object(actor: PrepObject, left: Hand, right: Hand) -> PrepObject:
	if left != null and left.holds == actor and right != null:
		return right.holds
	if right != null and right.holds == actor and left != null:
		return left.holds
	return null


## Cari target untuk `actor`: dulu objek di tangan lain, lalu objek tergeletak
## di meja. Null kalau tidak ada yang cukup dekat.
static func _resolve_target(actor: PrepObject, other: PrepObject, kind: int) -> PrepObject:
	if other != null and int(other.kind) == kind:
		if actor.global_position.distance_to(other.global_position) <= INTERACT_DIST:
			return other
		return null
	return _nearest_table_object(actor, kind)


## Objek tergeletak di meja yang paling dekat dengan `actor`.
static func _nearest_table_object(actor: PrepObject, kind: int) -> PrepObject:
	var tree := actor.get_tree()
	if tree == null:
		return null
	var best: PrepObject = null
	var best_dist := INTERACT_DIST
	for node in tree.get_nodes_in_group(PrepObject.GROUP):
		var obj := node as PrepObject
		if obj == null or obj == actor:
			continue
		if obj.held_by != null:
			continue
		if int(obj.kind) != kind:
			continue
		var d := actor.global_position.distance_to(obj.global_position)
		if d <= best_dist:
			best_dist = d
			best = obj
	return best
