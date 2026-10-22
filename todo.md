# Es Cekek — TODO (living task tracker)

> Every AI model MUST update this file after every code change. Read it first, pick the top pending task, and update the checkboxes as you go. Never silently change scope.

## ⚠️ Update Protocol (WAJIB)

At the end of EVERY session that touches code:

1. Tick the boxes of any task/acceptance-criteria you completed → `[x]`
2. Move the task you were working on to **🔄 In Progress** if it is not finished
3. Add a new line to **Session Log** (bottom of this file) describing what changed
4. Update the matching section in [`context.md`](context.md) — especially "Recent Changes", "Test Status", and "Known Issues"
5. If you introduced a known bug or left something half-done, **write it in "Known Issues" of `context.md` AND as a sub-task below** so the next model does not rediscover it

**Never** delete a task to make the list look clean. If a task is abandoned, mark it `[~]` (dropped) and say why.

## Legend

- `[x]` Done (verified by a passing test or a working in-game check)
- `[~]` Dropped / abandoned (with reason)
- `[ ]` Pending
- 🔄 = currently being worked on (only ONE task may be 🔄 at a time)

---

## 🔄 In Progress

> Task 16 (kontrol layar sentuh first-person) **selesai di T16–T17** — 346/346 hijau.
> Sekarang ada **T18: QA perangkat = TUGAS MANUAL** (user yang menguji & memberi verdict),
> lalu **T19: commit ke git**.

---

## ✍️ TUGAS MANUAL — User (T18): tes kontrol sentuh di perangkat

> Sesuai permintaan user: *"untuk test test device jadiakan dia task manual alias biar aku
> yang input sudah benar atau belum"*. Kode + asersi otomatis sudah hijau; yang tersisa
> adalah **rasa** (feel) — hanya bisa dinilai di HP.

### Cara menjalankan

1. `run.bat --build` (|Windows/Linux/macOS/Android) → `build/android/EsCekek.apk`.
   **Belum** di-build ulang sejak Task 16 — build yang ada masih versi Task 15.
2. Salin `build\android\EsCekek.apk` ke HP → ketuk di file manager → install
   (tidak butuh adb; lihat `Readme.md`).
   Alternatif tanpa export: `run.bat` di PC + **Godot Editor "Deploy to Android Device"**.
3. Masuk ke game → dekati meja → tekan **INTERACT** → mode first-person aktif.

### Yang perlu dicoba (isi hasilnya di bawah)

| # | Yang dites | Rahman | Catatan |
|---|---|---|---|
| M1 | **1 jari di objek** → objek terpegang tangan terdekat (kanan/kanan, kiri/kiri) | ☐ | |
| M2 | **1 jari di area kosong** → kamera bisa lihat kiri/kanan/atas/bawah | ☐ | |
| M3 | **2 jari** → tetap melihat, tidak mengambil objek | ☐ | |
| M4 | **Geser jari** saat objek dipegang → objek ikut bergerak | ☐ | |
| M5 | **Lepas di meja** → objek ditaruh di meja | ☐ | |
| M6 | **Tombol "Tukar Tangan"** → isi kedua tangan bertukar | ☐ | |
| M7 | **Tombol "Putar Badan"** → badan berputar 180° | ☐ | |
| M8 | **2 objek berdekatan** → langkah resep jalan (gunting+sachet, dsb) | ☐ | |
| M9 | Kecepatan & jangkauan look di layar sentuh | ☐ | |
| M10 | Ukuran tombol TUKAR/PUTAR terjangkau jari (≥ 48 dp) | ☐ | |

**Verdict user (isi sendiri):** _______________________________________________

**Kalau ada yang terasa salah, tulis di sini + how-to-reproduce:**

```
-
```

### Knob tuning yang bisa diubah kalau feel-nya kurang pas

| Parameter | Lokasi | Default | Efek |
|---|---|---|---|
| `Player.TOUCH_LOOK_SENS_SCALE` | `src/entities/Player.gd` | 1.0 | pengali sensitivitas look sentuh |
| `Player.TOUCH_MOUSE_SLOP` | `src/entities/Player.gd` | 48.0 | toleransi takeover mouse-tiruan ↔ jari (px) |
| `Player.PREP_START_PITCH` | `src/entities/Player.gd` | -25° | kemiringan pandang awal di meja |
| `Player.PREP_STAND_OFFSET` | `src/entities/Player.gd` | 1.5 | jarak pemain dari konter |
| `Player.LOOK_SENS` | `src/entities/Player.gd` | 0.22 | sensitivitas look (mouse + sentuh) |

---

## Pending

### Export — template & QA (sisa Task 11)

- [x] **Pasang export template Godot 4.7.2** → ✅ terpasang di
      `%APPDATA%\Godot\export_templates\4.7.2.stable` (35 file, unduhan sekali saja ±1,28 GB)
- [x] Export Windows lalu jalankan `build\windows\EsCekek.exe` → ✅ boot bersih
      (`EsCekek.exe --headless --quit-after 120`, tanpa error script)
- [x] Export Linux (`build\linux\EsCekek.x86_64`) + macOS (`build\macos\EsCekek.zip`) + Android (`build\android\EsCekek.apk`)
- [x] Android: SDK + JDK terpasang, `java_sdk_path` + debug keystore diset, ikon & nama package benar
      (`com.escekek.game`, minSdk 24, targetSdk 36)
- [x] Android: `.pck` < 100 MB → ✅ **3,4 MB** (naik dari 181 KB karena 197 mesh Kenney ikut ter-pack);
      permission minimal ✅ (tanpa permission tambahan)
- [x] **Android WAJIB `--export-debug`** — `--export-release` gagal signing ("Could not find release
      keystore") → APK sempat tertulis tapi **tidak signed**. `--export-debug` pakai debug keystore
      dari `editor_settings-4.7.tres` → signed + `.idsig` tergenerate
- [x] Periksa `VirtualJoystick` benar-benar menggerakkan pemain → ✅ bug diperbaiki (Task 11c) + 8 asersi regresi
- [ ] **Android: install `EsCekek.apk` di HP asli** → `adb devices` kosong, butuh perangkat tersambung
- [ ] Android: cek joystick + tombol prep + UI di ~1080×2340 & ~2560×1600 (menunggu perangkat)
- [x] **Task 14 — re-export 4 build** setelah Task 15 (Windows/Linux/macOS/Android) → ✅ via
      `run.bat --build` (2026-10-22): `EsCekek.exe` 109,1 MB (boot bersih), `EsCekek.x86_64` 73,5 MB,
      `EsCekek.zip` 62,9 MB, `EsCekek.apk` 89,8 MB **signed** (`--export-debug`, lihat gotcha #21)

### Polish (sisa Task 12)

- [ ] Voice keluhan pelanggan (saat ini bubble teks 3D)
- [ ] VFX sederhana: efek siram saat pours, hening saat aduk, kilau saat es masuk
- [ ] Warna tiap lokasi lebih berbeda (tint matahari per lokasi sudah ada, sisanya)
- [ ] Taste pass visual (tas 3D, bubble, pencahayaan) — belum pernah dilihat mata di editor
- [ ] Taste pass visual mesh Kenney (skala kursi/angkot, posisi kasir, kepadatan objek) —
      penempatan sudah diverifikasi **numerik** (AABB) tapi belum di-eye-ball

### Documentation

- [x] Update `1792500018425-es-cekek-mvp-plan.md` task checkboxes to mirror this file
- [x] Write / refresh `README.md` (how to run, how to test, how to export, what's missing)
- [x] Keep `context.md` current

---

## Done

### ✅ Task 16 — Kontrol layar sentuh mode first-person

> Permintaan user: *"oke buat aja dulu ktrol layart sentuhnya … untuk feelnya bisa tunggu
> instruksi dariku aja buat iterasi, dan untuk test test device jadikan dia task manual"*.

- [x] **T16a — `project.godot`**: emulasi input dibenahi —
      `pointing/emulate_touch_from_mouse=false` + `emulate_mouse_from_touch=true`
      (sebelumnya `true` membuat event tiba dobel → grab terputus)
- [x] **T16b — `src/entities/Player.gd`**: satu mesin state pointer
      `handle_prep_pointer(event)` untuk mouse + multi-jari (1 jari objek = ambil,
      1/2 jari area kosong = lihat, takeover mouse-tiruan ↔ jari, `TOUCH_MOUSE_SLOP` 48 px)
- [x] **T16c — `src/prep/PrepController.gd`**: API pointer eksplisit
      (`begin_drag_at` / `set_pointer` / `end_drag_at`) — controller tidak lagi baca
      event input sendiri
- [x] **T16d — `src/autoload/UILayer.gd`**: tombol layar **"Tukar Tangan"** (pengganti `Q`)
      & **"Putar Badan"** (pengganti `R`) lewat sinyal `prep_action`
      (`ACTION_SWAP_HAND` / `ACTION_TURN_BODY`); joystick disembunyikan saat mode prep
- [x] **T16e — fix geometri kamera** (bug nyata, bukan cuma test): `PREP_STAND_OFFSET`
      1,05 → 1,5, konstanta baru `PREP_START_PITCH = -25°`, `PrepController.REACH`
      1,30 → 2,2. Sebelum: **seluruh meja di luar layar** dan tidak bisa di-drag
- [x] **T16f — `tests/runtime_test.gd`**: `_test_task16()` 8 blok asersi (A–H) +
      helper `_find_pick_point()` / `_find_empty_point()` / `_restore_prep_state()`
      (koordinat layar dicari dinamis, tidak hardcode)
- [x] **T17 — suite hijau**: `scripts\run_tests.cmd` → **346/346 lolos, 0 gagal**
- [x] **T18a — alat ukur sementara dihapus**: `tools/input_probe.gd` + `tools/input_probe.tscn`
- [ ] **T18b — QA perangkat** → **TUGAS MANUAL user** (lihat bagian
      "✍️ TUGAS MANUAL — User (T18)" di atas)
- [ ] **T19 — commit ke git**

### ✅ Task 15 — First-person hands: racik es manual dengan dua tangan

> Rencana lengkap: [`plans/task-15-first-person-hands.md`](plans/task-15-first-person-hands.md).
> Keputusan user: **panel prep lama dihapus total**, semua langkah es lewat drag objek 3D.

- [x] **T1 — `src/prep/PrepObject.gd` + `src/prep/Hand.gd`**: 8 jenis objek meja
      (sachet/gunting/plastik/jerigen/cooler/serok/sendok/sedotan), `PICK_LAYER 2`,
      satu tangan = satu objek, enum `HandSide` (bukan `Side` — bentrok dengan tipe engine)
- [x] **T2 — `src/entities/Player.tscn` + `Player.gd`**: `PrepRig` (`top_level = true`) berisi
      `Camera3D` + `LeftHand`/`RightHand`, `PrepController`; state baru `PREP`; look pitch ±35° /
      yaw ±60°, badan bisa diputar 180° dengan `R`
- [x] **T3 — `src/prep/PrepController.gd`**: ray-pick objek, **tangan terdekat menang**,
      drag, `Q` tukar tangan, serah-terima ke pelanggan
- [x] **T4 — `src/stand/PrepStation.tscn`**: meja fisik — 4 sachet (1 per brand) + gunting +
      tumpukan plastik + jerigen air + cooler es + serok + sendok aduk + sedotan
- [x] **T5 — `src/prep/RecipeRules.gd`**: 7 pemicu langkah —
      `cut → pour_powder → pour_water → stir → fill_scoop → add_ice → add_straw`
- [x] **T6 — `src/stand/PrepStation.gd`**: mesin state resep — `step_history`,
      `out_of_order_count`, `missing_steps()`, `step_score()` (penalti `OUT_OF_ORDER_PENALTY 0.70`)
- [x] **T7 — `src/stand/Stand.gd`**: wiring sesi prep ↔ stand + `pickup_position()`
- [x] **T8 — `src/entities/Customer.gd`**: `complain_missing()` → `"Kurang: …"`,
      `come_to_counter()` supaya pelanggan bisa **mengambil tas sendiri**
- [x] **T9 — `src/autoload/UILayer.gd`**: **panel prep lama dibongkar total**; HUD minimal
      (harga + status pesanan + tombol **Serahkan**)
- [x] **T10 — `src/autoload/InputSetup.gd`**: `swap_hand` (Q), `prep_exit` (E/Esc),
      `turn_body` (R); binding langkah lama dihapus
- [x] **T11 — `tests/runtime_test.gd`**: `_test_task15()` 12 blok asersi (A–L) + revisi
      asersi lama (panel prep)
- [x] **T12 — `scripts\run_tests.cmd --boot`** → **314/314 hijau, 0 gagal, boot bersih**
- [x] **T13 — dokumentasi sinkron**: `context.md` (indeks file + `src/prep/`, alur penjualan,
      scene tree, parameter tuning, test status, known issues, recent changes), `todo.md`,
      `Readme.md`
- [x] **T14 — re-export 4 build** → `run.bat --build` (semua preset sukses, `.exe` boot bersih,
      `.apk` signed)

### ✅ Task 12c–12f — Asset 3D Kenney CC0 (karakter, lokasi, propsi stand) + re-export

- [x] **Task 12c — pipeline asset Kenney (CC0)**: `scripts/prepare_kenney_assets.ps1` mengunduh 6 pack
      resmi Kenney, mengambil subset, menyalin `Textures/colormap.png`, memaksa re-import
- [x] `assets/kenney/` = **197 GLB (10,6 MB)** + 4 colormap:
      `mini` 12 (karakter), `commercial` 25 (gedung toko), `suburban` 39 (rumah/pohon/pagar),
      `roads` 38 (aspal), `furniture` 33 (meja/kursi/lemari), `food` 50 (makanan/minuman/perabot)
- [x] Pack: Mini Characters, City Kit Commercial/Suburban/Roads, Furniture Kit, Food Kit — **CC0**,
      satu gaya low-poly konsisten
- [x] Parameter import GLB diverifikasi: `nodes/apply_root_scale=true`, `nodes/root_scale=1.0`,
      `materials/extract=0` → skala GLB terjaga 1:1
- [x] **Task 12d — karakter**: `src/entities/KenneyCharacter.gd` memuat 12 GLB mini-characters
      (`MODEL_SCALE 2.53`, `MODEL_YAW PI`) untuk player + pelanggan; pose kesal & bubble tetap jalan
- [x] **Task 12e — lokasi**: Pasar / Sekolah / Rumah dibangun dari mesh Kenney (gedung, tenda, jalan,
      rumah, pohon, pagar) — tiap lokasi benar-benar berbeda
- [x] **Task 12f — propsi stand**: meja konter (`table.glb` ×2,8), 3 kursi (`chair.glb` yaw 180° ×1,5),
      5 bangku antrean (`bench.glb` ×1,5), kasir (`computerScreen.glb`); prep: talenan
      (`cutting-board.glb`), cooler es (`barrel.glb`), dispenser air (`carton.glb`), wadah sedotan
      (`soda-can.glb`)
- [x] Marker `Seat_1..3` / `Queue_1..5` dihapus (kursi/bangku sendiri yang jadi marker) supaya
      `seat_positions()` / `queue_positions()` tetap 3 dan 5 (Implementer Decision #3 aman)
- [x] Penempatan diverifikasi **numerik** (AABB vertex-level): meja 0,915 m; semua properti di atas
      meja mulai y=0,920; kaki kursi/bangku di y=0
- [x] **Bug collision tersembunyi ditemukan & diperbaiki**: `CounterShape` ditulis tanpa
      `type="CollisionShape3D"` → jadi turunan `StaticBody3D`, assignment `shape` gagal diam-diam,
      `Counter` **tanpa collision shape** → `Player.InteractArea` tidak pernah mendeteksi stand →
      **panel prep tidak bisa dibuka saat main**. Ditutup asersi regresi baru
- [x] 7 asersi regresi baru (Counter StaticBody3D, CounterShape valid, 3 kursi, 5 antrean,
      mesh Kenney) → **246/246 hijau, boot OK**
- [x] **Re-export 4 build** setelah asset masuk: Windows 109,1 MB + pck **3,4 MB**, Linux 73,5 MB,
      macOS zip 62,9 MB, Android APK **89,8 MB signed** (`.idsig` ada)
- [x] `build\windows\EsCekek.exe --headless --quit-after 120` → boot bersih (hanya 2 ObjectDB leak)
- [x] `findstr /m /c:"assets/kenney" build\windows\EsCekek.pck` → asset Kenney **terbukti** ter-pack
- [x] Housekeeping: semua alat ukur sementara dihapus (`tools/*`, `scripts/run_layout.cmd`)

### ✅ Task 11b + 11c — Export template, 4 build, fix virtual joystick

- [x] Unduh `Godot_v4.7.2-stable_export_templates.tpz` (±1,28 GB) → ekstrak → 35 file template
      disalin ke `%APPDATA%\Godot\export_templates\4.7.2.stable`
- [x] Export **Windows** → `build/windows/EsCekek.exe` (109,1 MB) + `EsCekek.pck` (181 KB)
- [x] Export **Linux** → `build/linux/EsCekek.x86_64` (73,5 MB) + `EsCekek.pck` (181 KB)
- [x] Export **macOS** → `build/macos/EsCekek.zip` (59,9 MB, universal)
- [x] Export **Android** → `build/android/EsCekek.apk` (86,5 MB),
      `com.escekek.game`, minSdk 24, targetSdk 36, arm64-v8a/armeabi-v7a/x86_64
- [x] Dibuat folder `build/windows|linux|macos|android` (export gagal kalau folder output belum ada)
- [x] **Ikon aplikasi**: `assets/icon.png` (256×256, digambar via System.Drawing) +
      `config/icon="res://assets/icon.png"` di `project.godot` (Android menolak export tanpa ikon)
- [x] **Java SDK**: `export/android/java_sdk_path` diset ke JDK 17 di
      `%APPDATA%\Godot\editor_settings-4.7.tres` (sebelumnya kosong → export APK gagal)
- [x] **Debug keystore**: `%APPDATA%\Godot\keystores\debug.keystore` dibuat & diisi
- [x] Smoke test build: `EsCekek.exe --headless --quit-after 120` → boot bersih (hanya 2 ObjectDB leak)
- [x] **Bug virtual joystick diperbaiki**: `UILayer.set_move_vector(v: Vector2)` ditambahkan
      (`src/autoload/UILayer.gd`) + `VirtualJoystick._publish()` memanggilnya
      (`src/ui/VirtualJoystick.gd`) — sebelumnya method itu tidak pernah ada, jadi
      vektor gerak sentuh **tidak pernah sampai ke `Player`** (game di HP tidak bisa digerakkan)
- [x] 8 asersi regresi joystick baru di `tests/runtime_test.gd` → **233/233 hijau, boot OK**
- [x] Keempat build di-ekspor ulang setelah fix joystick

### ✅ Task 11a — Export presets + setelan Android + dokumentasi

- [x] `export_presets.cfg` untuk **Windows Desktop / Linux / macOS / Android**
- [x] Output diarahkan ke `build/` (`build/windows`, `build/linux`, `build/macos`, `build/android`)
- [x] `export_presets.cfg` tidak lagi di-ignore Git (preset = bagian dari project)
- [x] `project.godot`: `config/version="1.0.0"` + `renderer/rendering_method.mobile="gl_compatibility"` (Android dipaksa GLES3 untuk HP tanpa Vulkan)
- [x] Diverifikasi headless: preset terbaca, export hanya gagal karena **export template belum terpasang**
      → *(hambatannya sudah diselesaikan di Task 11b di bawah)*
- [x] `Readme.md` ditulis ulang: cara main (F5), kontrol, cara test headless, cara export, daftar yang belum selesai
- [x] `context.md` & `todo.md` disinkronkan (task row `11a`, test status, known issues, recent changes)
- [x] Suite tetap hijau setelah semua perubahan → **225/225, boot OK** *(nilai saat itu; sekarang **233/233** — lihat Task 11b + 11c)*

### ✅ Task 12 — Procedural SFX autoload (no external assets)

- [x] `src/autoload/Audio.gd` — autoload baru, **tanpa aset eksternal sama sekali**
- [x] Semua bunyi disintesis runtime sebagai `AudioStreamWAV` 16-bit PCM (44100 Hz)
- [x] 10 bunyi: `pour`, `water`, `stir`, `ice`, `straw`, `cash`, `complain`, `build`, `serve`, `ui`
- [x] Pool 8 `AudioStreamPlayer` supaya bunyi bisa overlap
- [x] Cache stream (`_cache`) supaya PCM tidak digenerate ulang
- [x] Musik ambient loop 2 detik (drone bass + pad) via `LOOP_FORWARD`
- [x] `set_enabled(false)` untuk bisukan semua SFX
- [x] `PrepStation` emits 5 sinyal baru: `pour_done`, `water_added`, `stirred`, `ice_added`, `straw_added`
- [x] `Stand._wire_sfx()` connect sinyal-sinyal itu ke bunyi
- [x] `Stand.serve_to()` → bunyi `cash` kalau pelanggan menerima
- [x] `Stand.serve_offered_to()` → bunyi `serve` saat menyerahkan tas
- [x] `Customer._on_complain()` → bunyi `complain` (menutup jalur salah brand + kemahalan)
- [x] 47 asersi baru di `tests/runtime_test.gd` → **225/225 hijau**

### ✅ Task 12 — 3D feedback (tas di meja, bubble keluhan, pose kesal)

- [x] `Stand.tscn` → node `BagVisual` (Shell / Liquid / Straw) di atas meja
- [x] Warna liquid mengikuti `brand.color_tint`
- [x] `prep_quality < 60` → warna liquid pudar (semakin rendah semakin pudar)
- [x] Es batu → warna liquid makin pucat ke arah putih
- [x] Volume menentukan tinggi liquid di dalam tas
- [x] Sedotan muncul kalau tas punya sedotan (`Bag.has_straw` baru)
- [x] `Stand.current_bag` jadi property dengan setter → tas 3D selalu sinkron
- [x] `Customer.tscn` → node `Bubble` (Label3D, billboard) di atas kepala
- [x] Bubble muncul otomatis dari sinyal `complain`, hilang setelah 2.4 detik
- [x] Pose kesal: badan memendek + menunduk + makin kemerahan
- [x] `target_crouch()` mengikuti `ANNOYANCE_TIERS`
- [x] 37 asersi baru di `tests/runtime_test.gd` → **178/178 hijau**

### ✅ Day/night lighting — `TimeOfDay` drives the real sun + sky (Task 4-L)

> Not a number from the MVP plan: the plan's Task 4 is "LocationManager + Pasar scene".
> This lighting task is tracked as **Task 4-L** in `context.md` → §10.

- [x] `Main.gd` hands `TimeOfDay.sun_light` (the persistent `Sun`) and
      `TimeOfDay.environment` (the persistent `WorldEnvironment`) to the singleton
- [x] Sun angle: rises at the start of the day, sets at `SUNSET_RATIO = 0.9`, night after that
- [x] Sun energy: 1.0 at noon → 0.4 at sunrise/sunset → 0.12 at night (moonlight)
- [x] Sun colour: warm `dusk_color` at dawn/dusk → bright `day_color` at noon → blue at night
- [x] Sky (`ProceduralSkyMaterial`) top + horizon colours follow the day
- [x] Ambient light colour/energy + fog follow the day
- [x] Per-location accent: `Location._apply_palette()` → `TimeOfDay.set_sun_tint()`
- [x] Fixed `Main.tscn`: `Environment.sky` pointed at a `ProceduralSkyMaterial`
      instead of a `Sky` resource → the sky never rendered
- [x] Fixed `TimeOfDay`: `fog_light_intensity` → `fog_light_energy` (Godot 4 name)
- [x] 14 new assertions in `tests/runtime_test.gd` → **141/141 green**

### ✅ Task 9 — UILayer polish (order queue, price slider, day-end detail)

- [x] Add `HUD/DayBar` ProgressBar to `src/ui/UILayer.tscn`
- [x] Restructure `DayEnd` → `DayEnd/Panel/Column` (Title / Summary / Detail / Continue)
- [x] Drive the day bar from `update_hud()` + `TimeOfDay.time_tick` → `_on_time_tick()`
- [x] **Write `_build_order_queue()`** in `src/autoload/UILayer.gd`
  - [x] Add an `OrderQueue` node to `src/ui/UILayer.tscn` (title label + `VBoxContainer` rows)
  - [x] Populate rows from the customers in group `customer` (brand + annoyance level, tinted yellow → red)
  - [x] Refresh it at most twice a second (`_on_time_tick`) and on every new order (`show_order`)
- [x] **Desktop price slider** (`_price_slider`, `HSlider`)
  - [x] Create the slider in the prep panel (visible on desktop, hidden on touch)
  - [x] Clamp to the offered bag's `[cost, fair_max]` (the cost is the real floor)
  - [x] Emit `ACTION_PRICE_SET` on change
  - [x] Route `ACTION_PRICE_SET` in `Stand._on_prep_action` → `Stand._set_price()` → `current_bag.sell_price`
- [x] **Richer day-end recap**: fill `DayEnd/Panel/Column/Detail` from the new recap keys
  - [x] `location_profit`, `rent_by_location`, `new_unlocks`
- [x] Extend `tests/runtime_test.gd` to cover the day bar, order queue and price slider (+18 assertions)
- [x] Re-run `scripts\run_tests.cmd` → **127/127 green**, boot without errors

### ✅ Task 8 — Economy depth (per-location rent, upgrade shop, unlocks)

- [x] `Economy.charge_rent(location_id)` — charged once per location per day
- [x] `Economy.rent_by_location()` accessor
- [x] Richer recap: `location_profit`, `rent_by_location`, `locations_used`, `new_unlocks`
- [x] `Economy.new_unlocks_for_day(day)`
- [x] `Tool` resource: `slot`, `unlock_day`, `is_upgrade`
- [x] `Catalog` split: `STARTUP_TOOL_PATHS` / `SHOP_TOOL_PATHS` + `startup_tools()` / `shop_tools()` / `all_tools()` / `available_on_day()`
- [x] `Inventory.buy_tool()` + `install_tool()` slot replacement
- [x] `StandEquipment` mirrors slots: `tool_in_slot()`, `ice_capacity()` from cooler slot, `quality_mod()` multiplies
- [x] `PrepStation.ice_capacity()` falls back to `MAX_SPOON_ICE`
- [x] Shop panel in `UILayer` + `TouchButtons/Shop` button
- [x] 27 new assertions in `tests/runtime_test.gd` → **109/109 green**

### ✅ Tasks 1–7, 10 — core game loop (see `context.md` for details)

- [x] Task 1 — project scaffolding, InputMap, folder layout
- [x] Task 2 — Location.tscn template (ground, light, NavMesh, stand slot)
- [x] Task 3 — Player.tscn (ROAM/AT_STAND, joystick + WASD, camera follow)
- [x] Task 4 — LocationManager + Pasar scene
- [x] Task 5 — SachetBrand + 4 brands, Tool + startup set, StandEquipment + Inventory
- [x] Task 6 — Stand.tscn + PrepStation.tscn, prep pipeline → Bag, refuse/serve path
- [x] Task 7 — Customer scene + spawner, annoyance tiers, serve evaluation
- [x] Task 10 — Sekolah + Rumah locations, travel wiring

### ✅ Test harness repair

- [x] Fixed the broken harness (was `--script` mode → `Identifier not found: Catalog`)
- [x] Converted to a scene: `tests/runtime_test.tscn` + `extends Node`
- [x] Suite runs headless via `scripts\run_tests.cmd`

---

## Known Issues (mirror of `context.md` → keep in sync)

- [x] ~~Bug joystick `set_move_vector`~~ — **DIPERBAIKI** (Task 11c): `UILayer.set_move_vector(v)` ditambahkan,
      `_publish()` memanggilnya, 8 asersi regresi baru. Suite **233/233**.
- [ ] The day/night lighting is only verified by headless assertions (energy / colour / angle / sky). The *visual* result has not been eyeballed in the editor yet — colours may need a taste pass
- [ ] The procedural SFX are only verified by headless assertions (stream PCM valid, 16-bit, the right event fires the right id). The *audible* result has not been listened to yet — the tones are placeholders and may need a taste pass
- [x] ~~`assets/` hanya berisi `icon.png` — belum ada art CC0~~ — **DIPERBAIKI** (Task 12c–12f):
      `assets/kenney/` kini berisi **197 GLB CC0** (karakter, lokasi, propsi stand) — tidak ada lagi
      geometri primitif sebagai visual utama
- [x] ~~`CounterShape` tanpa `type=` → counter tanpa collision → panel prep tak bisa dibuka~~
      — **DIPERBAIKI** (Task 12f): `type="CollisionShape3D"` ditambahkan + asersi regresi baru
- [x] ~~Export Android `--export-release` gagal signing~~ — **DIPERBAIKI**: pakai `--export-debug`
      (debug keystore) → APK 89,8 MB signed + `.idsig` tergenerate
- [ ] Gaya visual mesh Kenney **belum pernah dilihat mata** di editor — penempatan sudah diverifikasi
      numerik (AABB) tapi skala, jarak, dan kerapatan objek mungkin perlu taste pass
- [x] ~~Export template belum terpasang~~ — **DIPERBAIKI** (Task 11b): template terpasang,
      4 build sudah ada di `build/`. Tinggal install APK di HP asli (belum ada perangkat via adb).
- [ ] GPU PC ini tidak mendukung D3D12/Vulkan → Godot jatuh ke renderer Compatibility/OpenGL (game tetap jalan normal, tapi belum pernah dinilai secara visual)
- [ ] **QA di HP Android asli belum dilakukan** — tapi **tidak butuh adb**: APK sudah diverifikasi
      signed (`apksigner verify` → "Verifies", v2 + v3, signer `CN=Android Debug`), jadi cukup
      salin `build/android/EsCekek.apk` ke HP → ketuk file-nya di file manager → install.
- [x] ~~Gaya install Android selalu harus `adb install`~~ — **DIPERBAIKI**: `Readme.md`
      sekarang punya bagian **"Cara paling gampang — TANPA adb"** (copy via USB MTP / Drive /
      WhatsApp → ketuk `.apk` di HP → izinkan "Install unknown apps"). `.idsig` tidak perlu dikirim.
- [ ] Mode prep first-person (Task 15) **baru diverifikasi lewat asersi headless** — belum pernah
      dilihat mata di editor: posisi mesh gunting/serok/sendok, jangkauan `Hand.reach_radius`
      (0,45 m), dan jarak plumpeng antarobjek mungkin perlu taste pass
- [x] ~~Build di `build/` masih versi panel prep lama~~ — **DIPERBAIKI** (T14, 2026-10-22):
      4 build di-ekspor ulang via `run.bat --build` → Windows/Linux/macOS/Android,
      `.exe` boot bersih, `.apk` signed
- [x] ~~Kontrol sentuh mode racik first-person **masih setengah jadi**~~ — **DIPERBAIKI (Task 16)**:
      satu mesin state pointer (`Player.handle_prep_pointer`) untuk mouse + multi-jari,
      takeover mouse-tiruan ↔ jari, tombol layar **Tukar Tangan**/**Putar Badan**.
      Suite **346/346**
- [ ] **"Feel" kontrol sentuh belum dinilai** — semua Task 16 diverifikasi lewat asersi
      headless. Sesuai permintaan user, tes device jadi **TUGAS MANUAL** (lihat bagian
      "✍️ TUGAS MANUAL — User (T18)"). Knob tuning: `TOUCH_LOOK_SENS_SCALE`,
      `TOUCH_MOUSE_SLOP`, `PREP_START_PITCH`
- [ ] **Build 4 target masih versi Task 15** — Task 16 belum di-ekspor ulang; perlu
      `run.bat --build` sebelum APK dikirim ke HP

---

## Session Log

| Date | Session | Changes | Test result |
|---|---|---|---|
| 2026-10-22 | Task 16 — kontrol layar sentuh first-person | **Satu mesin state pointer** di `Player.handle_prep_pointer()` untuk mouse + multi-jari (1 jari objek = ambil, 1/2 jari area kosong = lihat, takeover mouse-tiruan ↔ jari via `TOUCH_MOUSE_SLOP`); **emulasi input dibenahi** (`emulate_touch_from_mouse=false` + `emulate_mouse_from_touch=true` → event tidak dobel); **API pointer eksplisit** di `PrepController` (`begin_drag_at`/`set_pointer`/`end_drag_at`); **tombol layar "Tukar Tangan" & "Putar Badan"** (`UILayer.prep_action`); **fix geometri kamera** (`PREP_STAND_OFFSET` 1,05→1,5, `PREP_START_PITCH` -25° baru, `REACH` 1,30→2,2 — sebelumnya **seluruh meja di luar layar** dan tidak bisa di-drag); `_test_task16()` 8 blok asersi + helper cari koordinat dinamis; **gotcha baru #22** (ray-pick baca state fisika frame sebelumnya → butuh 1 `physics_frame` setelah `reparent`); probe `tools/input_probe.*` dihapus; `todo.md` dapat bagian **✍️ TUGAS MANUAL (T18)** untuk user | 346/346 ✅ 0 gagal |
| 2026-10-22 | `run.bat` — main game dari source tanpa export | File baru `run.bat` di root project: auto-deteksi binary Godot (`%LOCALAPPDATA%\Godot\`, bisa di-override dgn env `GODOT`), mode `play` (default, main scene dari source — **tanpa export/build**), `--editor`, `--test` (smoke test + boot check), `--build` (export 4 platform sekaligus: `--export-release` ×3 + `--export-debug` Android), `--headless`, `--help`; argumen lain diteruskan ke Godot; `pause` di akhir. Docs (`context.md` §3.1, `todo.md`, `Readme.md`) disinkronkan | 314/314 ✅ boot OK (`run.bat --test`) |
| 2026-10-22 | Task 15 — first-person hands | **Panel prep lama dihapus total** (`UILayer` → HUD minimal: harga + status pesanan + tombol **Serahkan**). **Baru**: `src/prep/` (`PrepObject.gd`, `Hand.gd`, `PrepController.gd`, `RecipeRules.gd`); `Player.tscn` dapat `PrepRig` (kamera + 2 `Hand`) + `PrepController` dan state `PREP`; `PrepStation.tscn` jadi meja fisik (4 sachet + gunting + plastik + jerigen + cooler + serok + sendok + sedotan); `RecipeRules` 7 pemicu (`cut → pour_powder → pour_water → stir → fill_scoop → add_ice → add_straw`) dengan penalti urutan; **tangan terdekat menang** (`_choose_hand`), `Q` tukar tangan; pelanggan **komplain** kalau belum siap (`"Kurang: …"`) dan **ambil sendiri** kalau sudah siap. `tests/runtime_test.gd` + `_test_task15()` (12 blok asersi A–L). Docs (`context.md`, `todo.md`, `Readme.md`) disinkronkan | 314/314 ✅ boot OK |
| 2026-10-21 | Cara install APK tanpa adb | APK diverifikasi **signed** via `apksigner verify` → "Verifies", skema v2 + v3, signer `CN=Android Debug` (RSA 2048) → aman di-*sideload*. `Readme.md` ditambah bagian **"⭐ Cara paling gampang — TANPA adb"** (copy via USB MTP / Google Drive / WhatsApp → ketuk `.apk` di file manager → izinkan "Install unknown apps"); `adb` jelasin sebagai **alternatif** (full path `C:\Users\WIN10\AppData\Local\Android\Sdk\platform-tools\adb.exe`, belum ada di PATH); catatan `.idsig` tidak perlu dikirim ke HP | 246/246 ✅ (tidak ada perubahan kode — docs only) |
| 2026-10-21 | Commit ke GitHub | Semua pekerjaan Task 12c–12f + 13 + 14 di-commit & push ke `origin/master` (`https://github.com/ieu-iz/Es-Cekek.git`): commit `6f6b967`, 470 file, +15.373 baris. File sampah `ERR')` dihapus. Push pertama **ditolak** (remote punya commit `8054e42 "add readme"` yang belum ada di lokal) → diselesaikan via `git rebase origin/master` + resolusi konflik `Readme.md` add/add (versi lokal yang lebih baru dipertahankan). Branch `worktree/zoocode` **tidak** disentuh. Verifikasi setelah rebase: 246/246 hijau, boot bersih, `git grep` tidak menemukan conflict marker | 246/246 ✅ boot OK |
| 2026-10-21 | Task 12c–12f + re-export | Pipeline asset Kenney CC0 (`scripts/prepare_kenney_assets.ps1`) → `assets/kenney/` 197 GLB (10,6 MB) + 4 colormap; karakter player/pelanggan pakai mini-characters GLB; 3 lokasi dibangun dari mesh Kenney; propsi stand (meja konter, 3 kursi, 5 bangku, kasir, rak prep) diganti mesh sungguhan; **bug collision tersembunyi ditemukan** (`CounterShape` tanpa `type=` → `Counter` tanpa collision shape → panel prep tak bisa dibuka saat main) + 7 asersi regresi; 4 build di-ekspor ulang (Windows pck 181 KB → 3,4 MB, Android **harus `--export-debug`** supaya signed); alat ukur sementara dihapus; `context.md`/`todo.md`/`Readme.md`/plan disinkronkan | 246/246 ✅ boot OK (exe boot bersih) |
| 2026-10-21 | Task 11b + 11c | Export template Godot 4.7.2 terpasang (35 file di `%APPDATA%\Godot\export_templates\4.7.2.stable`); 4 build headless sukses — Windows `.exe` 109,1 MB (boot bersih), Linux 73,5 MB, macOS zip 59,9 MB, Android APK 86,5 MB (`com.escekek.game`); `assets/icon.png` dibuat + `config/icon` diset (Android butuh ikon); `java_sdk_path` + debug keystore diset di `editor_settings-4.7.tres`; **bug virtual joystick diperbaiki** (`set_move_vector` tidak pernah ada → gerak sentuh tak pernah sampai ke `Player`); 8 asersi regresi baru; dokumen (`context.md`/`todo.md`/`Readme.md`/plan) disinkronkan | 233/233 ✅ boot OK |
| 2026-10-21 | Task 11a + Docs | `export_presets.cfg` (Windows/Linux/macOS/Android) + `project.godot` (`config/version`, `renderer/rendering_method.mobile=gl_compatibility`) + `.gitignore` (preset ikut di-commit) + `Readme.md` ditulis ulang (main/test/export) + `context.md`/`todo.md` disinkronkan; verifikasi export headless (preset OK, blocker hanya export template) | 225/225 ✅ boot OK |
| 2026-10-21 | Task 12 (SFX) | Autoload `Audio` baru (`src/autoload/Audio.gd`): 10 bunyi disintesis runtime sebagai `AudioStreamWAV` 16-bit PCM, pool 8 `AudioStreamPlayer`, cache stream, musik ambient loop; `PrepStation` emits 5 sinyal langkah baru; `Stand` connect ke bunyi + `cash`/`serve`; `Customer` → `complain`; 47 asersi baru | 225/225 ✅ boot OK |
| 2026-10-21 | Task 12 (3D feedback) | Tas 3D di meja (`BagVisual`: Shell/Liquid/Straw) dengan warna brand, pudar saat kualitas rendah, makin pucat saat ada es, tinggi liquid ikut volume; `Bag.has_straw` baru; `Stand.current_bag` jadi property dengan setter; bubble keluhan 3D (`Label3D` billboard) yang muncul dari sinyal `complain` dan hilang setelah 2.4 detik; pose kesal (jongkok + menunduk + merah); 37 asersi baru | 178/178 ✅ boot OK |
| 2026-10-21 | Docs (lighting) | `context.md` refreshed for the lighting work: new `TimeOfDay.gd` API row, new `src/Main.gd` + `Main.tscn` index rows, `Location.gd` → `set_sun_tint()`, Main scene tree, 3 new Godot gotchas, task table row 4-L, known issues synced | 141/141 ✅ boot OK |
| 2026-10-21 | Lighting | `TimeOfDay` now drives the real sun + sky + ambient + fog; `Main.gd` hands over the persistent sun/environment; `Location` gives the per-location accent; fixed the `Environment.sky` resource type and `fog_light_energy`; +14 assertions | 141/141 ✅ boot OK |
| 2026-10-21 | Task 9 | Order queue panel + live rows, desktop price slider, richer day-end detail, `ACTION_PRICE_SET` → `Stand._set_price()`, fixed the `.tscn` inline-style parse error, fixed 2 bugs found by the new tests (queue rows piling up, slider clobbering the price), +18 assertions | 127/127 ✅ boot OK |
| 2026-10-21 | Task 8 | Per-location rent, typed-array fixes in Catalog, shop panel + TOKO button, slot model across StandEquipment/Inventory/PrepStation, 27 new assertions | 109/109 ✅ |
| 2026-10-21 | Task 9 (start) | `HUD/DayBar` ProgressBar, `DayEnd` → `DayEnd/Panel/Column` restructure, day-bar wiring, declared order-queue/price-slider vars | ❌ broken (missing `_build_order_queue()`) |
| 2026-10-21 | Docs | Created `context.md` + `todo.md` as mandatory living documents for all AI models | n/a |
