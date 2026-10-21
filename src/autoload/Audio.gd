## Audio.gd
# Autoload singleton — procedural SFX ONLY, NO external assets.
# Semua bunyi disintesis saat runtime memakai AudioStreamWAV 16-bit PCM,
# lalu diputar lewat pool AudioStreamPlayer.
#
# Cara pakai:
#   Audio.play("pour")          -> bunyi satu kali
#   Audio.set_enabled(false)   -> bisukan semua SFX (dipakai saat uji)
#   Audio.start_ambient()      -> musik loop sederhana
extends Node

signal sfx_ready

## Jumlah player dalam pool (batas bunyi yang bisa overlap).
const POOL_SIZE: int = 8
## Sample rate untuk semua stream yang dibuat.
const SAMPLE_RATE: int = 44100

## Matikan semua efek suara.
var _enabled: bool = true
## Pool player supaya tidak ada AudioStreamPlayer baru tiap bunyi.
var _pool: Array[AudioStreamPlayer] = []
## Cache stream supaya PCM tidak digenerate ulang tiap kali bunyi dimainkan.
var _cache: Dictionary = {}
## Player khusus musik ambient (loop).
var _ambient_player: AudioStreamPlayer = null
## Bunyi terakhir yang dimainkan (dipakai tes + debugging).
var last_played: StringName = &""
## Riwayat bunyi yang dimainkan (maks 64 entri terakhir).
var play_log: Array[StringName] = []
## Berapa kali bunyi sudah dimainkan (statistik sederhana).
var play_count: int = 0


func _ready() -> void:
	_build_pool()
	sfx_ready.emit()
	start_ambient()


func _build_pool() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		add_child(p)
		_pool.append(p)


## Aktifkan / nonaktifkan semua SFX.
func set_enabled(v: bool) -> void:
	_enabled = v


func is_enabled() -> bool:
	return _enabled


# --- Stream factories ----------------------------------------------------

## Buat stream 16-bit mono dari fungsi pembentuk sample.
## `sampler(i, t)` harus mengembalikan nilai -1..1.
func _make_stream(sampler: Callable, seconds: float) -> AudioStreamWAV:
	var total: int = maxi(int(seconds * SAMPLE_RATE), 1)
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	for i in range(total):
		var t := float(i) / float(SAMPLE_RATE)
		var v: float = clampf(float(sampler.call(i, t)), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream


## Stream sinus sederhana dengan amplop yang meluruh (decay).
func _tone(freq: float, seconds: float, vol: float, decay: float) -> AudioStreamWAV:
	return _make_stream(func(_i: int, t: float) -> float:
		return sin(TAU * freq * t) * exp(-decay * t) * vol
	, seconds)


## Stream derau putih dengan amplop yang meluruh — untuk suara "dingin".
func _noise(seconds: float, vol: float, decay: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	return _make_stream(func(_i: int, t: float) -> float:
		return rng.randf_range(-1.0, 1.0) * exp(-decay * t) * vol
	, seconds)


# --- Sound definitions ---------------------------------------------------

## Definisi bunyi: nama -> callable yang membuat stream.
func _make_sfx(id: StringName) -> AudioStreamWAV:
	match id:
		&"pour":
			# Tuang sachet: nada rendah bergelombang.
			return _tone(180.0, 0.35, 0.28, 6.0)
		&"water":
			# Tambah air: bunyi "klik" air naik.
			return _tone(760.0, 0.18, 0.24, 9.0)
		&"stir":
			# Aduk: desis + gesekan.
			return _noise(0.45, 0.16, 4.0)
		&"ice":
			# Es batu: dentingan singkat.
			return _noise(0.16, 0.30, 14.0)
		&"straw":
			# Sedotan: bunyi plastik.
			return _tone(520.0, 0.12, 0.20, 11.0)
		&"cash":
			# K waved: dua not tinggi berurutan.
			return _make_stream(func(i: int, t: float) -> float:
				var half := 0.09
				var f := 880.0 if t < half else 1320.0
				var local := t if t < half else t - half
				return sin(TAU * f * local) * exp(-11.0 * local) * 0.30
			, 0.24)
		&"complain":
			# Pelanggan kesal: nada rendah naik sedikit.
			return _tone(170.0, 0.40, 0.30, 3.0)
		&"build":
			# Tas jadi: not naik singkat.
			return _tone(440.0, 0.20, 0.24, 8.0)
		&"serve":
			# Es diserahkan: not turun singkat.
			return _tone(660.0, 0.20, 0.24, 8.0)
		&"ui":
			# Ketukan UI: klik pendek.
			return _tone(880.0, 0.06, 0.16, 22.0)
		_:
			return _tone(440.0, 0.10, 0.20, 12.0)


## Nama bunyi yang tersedia.
func sfx_ids() -> Array[StringName]:
	return [
		&"pour", &"water", &"stir", &"ice", &"straw",
		&"cash", &"complain", &"build", &"serve", &"ui",
	]


# --- Playback ------------------------------------------------------------

## Mainkan bunyi berdasarkan nama. Aman dipanggil berkali-kali.
func play(id: StringName) -> void:
	if not _enabled:
		return
	last_played = id
	play_count += 1
	play_log.append(id)
	while play_log.size() > 64:
		play_log.pop_front()
	var stream: AudioStreamWAV = _stream_for(id)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	# Semua player dipakai — pakai yang pertama (paling tua).
	if _pool.size() > 0:
		var p0 := _pool[0]
		p0.stream = stream
		p0.play()


## Stream untuk sebuah id, dari cache (dibuat saat pertama dipakai).
func _stream_for(id: StringName) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id] as AudioStreamWAV
	var stream := _make_sfx(id)
	_cache[id] = stream
	return stream


# --- Ambient music -------------------------------------------------------

## Musik ambient sederhana: drone bass + pad, loop 2 detik.
func start_ambient() -> void:
	if _ambient_player != null:
		return
	var stream := _make_ambient()
	var p := AudioStreamPlayer.new()
	p.name = "AmbientPlayer"
	p.stream = stream
	p.volume_db = -14.0
	add_child(p)
	_ambient_player = p
	p.play()


func stop_ambient() -> void:
	if _ambient_player == null:
		return
	_ambient_player.stop()
	_ambient_player.queue_free()
	_ambient_player = null


func _make_ambient() -> AudioStreamWAV:
	var seconds: float = 2.0
	var stream := _make_stream(func(_i: int, t: float) -> float:
		var bass := sin(TAU * 55.0 * t) * 0.10
		var pad := sin(TAU * 220.0 * t) * 0.05 + sin(TAU * 330.0 * t) * 0.035
		return bass + pad
	, seconds)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(seconds * SAMPLE_RATE)
	return stream
