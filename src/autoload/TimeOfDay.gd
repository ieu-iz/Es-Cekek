## TimeOfDay.gd
# Singleton. Plan §TimeOfDay: DAY_SECONDS=180 (3-min day). Drives sun/sky lighting.
# Tuned via TimeOfDay.DAY_SECONDS (Implementer Decision #5).
extends Node

signal day_advanced(day_index: int)
signal day_ended(day_index: int)
signal time_tick(elapsed: float, normalized: float)  # normalized 0..1 within day

const DAY_SECONDS: float = 180.0       # plan tuning table
const DAWN_NIGHT_RATIO: float = 0.25

@export var current_day: int = 1
var _elapsed: float = 0.0
var _running: bool = false

var sun_light: DirectionalLight3D = null
var environment: WorldEnvironment = null

var day_color := Color(1.0, 0.95, 0.75)
var dusk_color := Color(0.8, 0.6, 0.4)
var night_color := Color(0.05, 0.08, 0.25)


func start_day(day: int = 1) -> void:
	current_day = day
	_elapsed = 0.0
	if not _running:
		_running = true
	_update_lighting(0.0)


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


func _update_lighting(norm: float) -> void:
	if sun_light != null:
		sun_light.rotation_degrees = _sun_angle(norm)
		sun_light.light_energy = _sun_energy(norm)
	if environment != null:
		var env := environment.environment
		if env != null:
			env.fog_light_intensity = _sun_energy(norm) * 0.4


func _sun_angle(norm: float) -> Vector3:
	var elev := sin(clampf((norm - 0.25) * PI, -PI / 2.0, PI / 2.0))
	var az := fmod(lerp(0.0, 360.0, norm), 360.0)
	return Vector3(elev * 90.0 + 90.0, az, 0.0)


func _sun_energy(norm: float) -> float:
	var t := clampf(sin(clampf((norm - 0.25) * PI, -PI / 2.0, PI / 2.0)), 0.0, 1.0)
	return lerp(0.15, 1.0, t)
