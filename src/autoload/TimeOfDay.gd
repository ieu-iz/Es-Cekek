## TimeOfDay.gd
# Singleton. Plan §TimeOfDay: DAY_SECONDS=180 (3 menit sehari).
# Menggerakkan jam hari + pencahayaan matahari dan langit.
# Setelan utama: TimeOfDay.DAY_SECONDS (Implementer Decision #5).
extends Node

signal day_advanced(day_index: int)
signal day_ended(day_index: int)
signal time_tick(elapsed: float, normalized: float)  # normalized 0..1 dalam sehari

const DAY_SECONDS: float = 180.0       # tabel setelan plan
const DAWN_NIGHT_RATIO: float = 0.25
## Matahari terbit saat hari mulai dan terbenam pada rasio waktu ini.
## Sisanya (sampai 1.0) adalah malam — shift pemain berakhir saat gelap.
const SUNSET_RATIO: float = 0.9

@export var current_day: int = 1
var _elapsed: float = 0.0
var _running: bool = false

## Matahari milik dunia persisten (dipasang oleh Main.gd).
var sun_light: DirectionalLight3D = null
## WorldEnvironment milik dunia persisten (dipasang oleh Main.gd).
var environment: WorldEnvironment = null
## Aksen warna per lokasi (dipasang oleh Location._apply_palette()).
var sun_tint: Color = Color(1.0, 1.0, 1.0)

## Warna cahaya matahari saat siang.
var day_color := Color(1.0, 0.95, 0.75)
## Warna cahaya matahari saat fajar / senja.
var dusk_color := Color(0.95, 0.6, 0.35)
## Warna ambient malam.
var night_color := Color(0.05, 0.08, 0.25)
## Warna cahaya bulan saat malam.
var night_light_color := Color(0.35, 0.45, 0.7)

## Warna langit (ProceduralSkyMaterial).
var day_sky_top := Color(0.36, 0.55, 0.82)
var day_sky_horizon := Color(0.72, 0.8, 0.88)
var dusk_sky_horizon := Color(0.95, 0.6, 0.35)
var night_sky_top := Color(0.02, 0.03, 0.10)
var night_sky_horizon := Color(0.08, 0.10, 0.20)


func start_day(day: int = 1) -> void:
	current_day = day
	_elapsed = 0.0
	if not _running:
		_running = true
	_update_lighting(_normalized())


func stop() -> void:
	_running = false


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var norm := clampf(_elapsed / DAY_SECONDS, 0.0, 1.0)
	time_tick.emit(_elapsed, norm)
	_update_lighting(norm)
	if _elapsed >= DAY_SECONDS:
		_end_current_day()


func elapsed_seconds() -> float:
	return _elapsed


func _end_current_day() -> void:
	_running = false
	day_ended.emit(current_day)
	# current_day is incremented by Economy.end_day() to keep a single source of truth.


func end_day_manual() -> void:
	if _running:
		_end_current_day()


func is_daytime() -> bool:
	var n := _normalized()
	return n >= DAWN_NIGHT_RATIO and n <= (1.0 - DAWN_NIGHT_RATIO)


func _normalized() -> float:
	return clampf(_elapsed / DAY_SECONDS, 0.0, 1.0)


# --- Pencahayaan ---------------------------------------------------------

## Terapkan pencahayaan untuk waktu ternormalisasi tertentu.
## Dipakai juga oleh tes dan saat lokasi berganti (warna aksen ikut berubah).
func apply_lighting(norm: float) -> void:
	_update_lighting(clampf(norm, 0.0, 1.0))


## Aksen warna matahari untuk lokasi ini. Tiap lokasi punya warna sendiri
## supaya tiga peta terlihat berbeda, tapi warna siang/malam tetap terbaca.
func set_sun_tint(color: Color) -> void:
	sun_tint = color
	apply_lighting(_normalized())


## Update seluruh pencahayaan (matahari + langit + ambient + kabut).
func _update_lighting(norm: float) -> void:
	var height := _sun_height(norm)
	var energy := _sun_energy(norm)
	var light_col := _light_color(norm)

	if sun_light != null:
		sun_light.rotation_degrees = _sun_angle(norm)
		sun_light.light_energy = energy
		# Aksen lokasi hanya menggeser sedikit supaya gradasi tetap terbaca.
		sun_light.light_color = light_col.lerp(sun_tint, 0.25)

	if environment == null:
		return
	var env := environment.environment
	if env == null:
		return

	var dayness := clampf(height, 0.0, 1.0)
	env.ambient_light_color = _ambient_color(norm)
	env.ambient_light_energy = lerpf(0.35, 0.65, dayness)
	env.fog_light_color = env.ambient_light_color
	# Godot 4 memakai `fog_light_energy` (bukan `fog_light_intensity`).
	env.fog_light_energy = energy * 0.4

	var sky := env.sky
	if sky == null:
		return
	var sky_mat := sky.sky_material as ProceduralSkyMaterial
	if sky_mat == null:
		return
	sky_mat.sky_top_color = night_sky_top.lerp(day_sky_top, dayness)
	var horizon := night_sky_horizon
	if height >= 0.0:
		horizon = dusk_sky_horizon.lerp(day_sky_horizon, clampf(height * 1.6, 0.0, 1.0))
	sky_mat.sky_horizon_color = horizon


## Ketinggian matahari: 0 saat terbit/terbenam, 1 saat tengah hari,
## negatif (di bawah horizon) saat malam.
func _sun_height(norm: float) -> float:
	if norm >= SUNSET_RATIO:
		# Malam: matahari terus turun ke bawah horizon.
		return -(norm - SUNSET_RATIO) / (1.0 - SUNSET_RATIO)
	return sin((norm / SUNSET_RATIO) * PI)


## Sudut matahari: pitch mengikuti ketinggian, yaw berputar sekali sehari.
func _sun_angle(norm: float) -> Vector3:
	var height := _sun_height(norm)
	var pitch := -clampf(height, -1.0, 1.0) * 70.0
	var yaw := lerpf(-30.0, 210.0, clampf(norm, 0.0, 1.0))
	return Vector3(pitch, yaw, 0.0)


## Kekuatan cahaya matahari: terang saat siang, redup (bulan) saat malam.
func _sun_energy(norm: float) -> float:
	var height := _sun_height(norm)
	if height < 0.0:
		return lerpf(0.35, 0.12, clampf(-height, 0.0, 1.0))
	return lerpf(0.4, 1.0, clampf(height, 0.0, 1.0))


## Warna cahaya matahari: senja hangat, siang terang, malam biru.
func _light_color(norm: float) -> Color:
	var height := _sun_height(norm)
	if height < 0.0:
		return night_light_color
	return dusk_color.lerp(day_color, clampf(height * 1.6, 0.0, 1.0))


## Warna ambient: biru gelap saat malam, terang saat siang.
func _ambient_color(norm: float) -> Color:
	var height := _sun_height(norm)
	if height < 0.0:
		return night_color
	var warm := dusk_color.lerp(day_color, clampf(height * 1.6, 0.0, 1.0))
	return night_color.lerp(warm, clampf(height * 3.0, 0.0, 1.0))
