# Es Cekek — Project Context (living snapshot)

> **WAJIB / MANDATORY:** every AI model reads this file FIRST and updates it after EVERY code change.
> See [`todo.md`](todo.md) for the task list and [`AGENTS.md`](AGENTS.md) for the workflow contract.

---

## 1. Project Overview

- **Name**: Es Cekek
- **Goal**: 3D Godot 4.x simulation of an Indonesian "es di kantong plastik" (plastic-bag ice / rendengan) street stand. Roam between locations (Pasar/Sekolah/Rumah), pick stand slot, receive shouted orders, pick right sachet, prep bag (pour → water → stir → ice → straw), price, serve. Quality = sachet price tier × correctness × tools. **NO minigames.**
- **MVP v1 ships**: Windows/Mac/Linux + Android APK. Web/iOS/console deferred. No network. Single player.
- **Working dir**: `c:/Users/WIN10/Documents/Project/Es Cekek`
- **Godot binary**: `C:\Users\WIN10\AppData\Local\Godot\Godot_v4.7.2-stable_win64_console.exe` (override with the `GODOT` env var)

### Quick commands

```
scripts\run_tests.cmd            # headless smoke test  -> "=== Selesai: N/N cek lolos, 0 gagal ==="
scripts\run_tests.cmd --boot     # same + boot the game headless for 120 frames
```

**Never** run the suite with `godot --script` — it breaks autoload resolution (see §9 Gotcha #1).

---

## 2. Folder Structure

```
Es Cekek/
├── project.godot                 Godot project config: autoload order, input, display, renderer
├── export_presets.cfg            Export presets: Windows / Linux / macOS / Android (Task 11)
├── AGENTS.md                     Mandatory workflow for every AI agent
├── context.md                    THIS FILE — living architecture + file index
├── todo.md                       Living task tracker (checkboxes, session log)
├── Readme.md                     Public readme: cara main, cara test, cara export
├── 1792500018425-es-cekek-mvp-plan.md   Original MVP plan (source of truth for design)
│
├── assets/
│   ├── icon.png                  256×256 app icon (ikon project + ikon launcher Android)
│   └── kenney/                   Mesh 3D CC0 (Kenney) — 197 GLB, 10,6 MB total
│       ├── mini/                 12 GLB  — 12 karakter (player + pelanggan)
│       ├── commercial/           25 GLB  — gedung toko (+ Textures/colormap.png)
│       ├── suburban/             39 GLB  — rumah, pohon, pagar (+ Textures/colormap.png)
│       ├── roads/                38 GLB  — aspal, marka jalan, trotoar
│       ├── furniture/            33 GLB  — meja, kursi, bangku, lemari, monitor
│       └── food/                 50 GLB  — makanan, minuman, perabot (+ Textures/colormap.png)
├── data/                         Resource data (.tres) — pure data, no logic
│   ├── brands/                   4 sachet brands: tejus, marimas, jasjus, frenta
│   ├── locations/                3 location defs: pasar, sekolah, rumah
│   └── tools/                    6 tools: table, sachet_hook, water_dispenser,
│                                 ice_cooler_small (startup) + ice_cooler_large, mixer (shop)
├── locations/                    World scenes, one per location
│   ├── pasar.tscn                Instances Location.tscn
│   ├── sekolah.tscn              Instances Location.tscn
│   └── rumah.tscn                Instances Location.tscn
├── scripts/
│   ├── run_tests.cmd             Windows batch test runner (headless)
│   └── prepare_kenney_assets.ps1 Pipeline unduh + subset + import asset Kenney (CC0)
├── build/                        (GIT-IGNORED) output export: exe / apk / zip
│   ├── windows/EsCekek.exe       Build Windows release (+ EsCekek.pck)
│   ├── linux/EsCekek.x86_64      Build Linux x86_64 (+ EsCekek.pck)
│   ├── macos/EsCekek.zip         Build macOS universal
│   └── android/EsCekek.apk       APK Android (arm64-v8a, armeabi-v7a, x86_64)
├── src/
│   ├── Main.gd / Main.tscn       Entry scene: boot, wiring, day cycle
│   ├── autoload/                 Global singletons (registered in project.godot)
│   ├── entities/                 Game actors (Player, Customer, Location, Spawner)
│   ├── resources/                Resource classes (Bag, Tool, Brand, LocationDef, Portion)
│   ├── stand/                    The stand (Stand, StandEquipment, PrepStation)
│   └── ui/                       UI scene + joystick script
├── tests/
│   ├── runtime_test.gd           Headless smoke test (the whole test suite)
│   └── runtime_test.tscn         Test harness scene (MUST be run as a scene, not --script)
└── tools/                        (KOSONG) alat ukur sementara (AABB/measure/inspect) — semua dihapus
```

> `*.uid` files next to every `.gd` are Godot 4.4+ resource UID caches. **Never hand-edit them.**

---

## 3. File Index (purpose + key API)

### 3.1 Root

| File | Purpose | Key API |
|---|---|---|
| `project.godot` | Autoload registration/order, InputMap seed, display 1280×720, mobile renderer, ETC2 textures | `[autoload]` order is load-bearing; `renderer/rendering_method="mobile"` + `renderer/rendering_method.mobile="gl_compatibility"` (Android dipaksa GLES3); `config/icon="res://assets/icon.png"` (wajib untuk export Android); `config/version="1.0.0"` |
| `export_presets.cfg` | Preset export: **Windows Desktop**, **Linux**, **macOS**, **Android** → output ke `build/` | Butuh export template Godot 4.7.2 terpasang (**sudah ✅** di `%APPDATA%\Godot\export_templates\4.7.2.stable`); Android butuh SDK+JDK+debug keystore (**sudah ✅** diset di `editor_settings-4.7.tres`). **Android WAJIB pakai `--export-debug`** — `--export-release` mencari *release* keystore yang tidak ada → gagal signing (lihat gotcha #21) |
| `AGENTS.md` | Mandatory read/update workflow for every AI agent | — |
| `context.md` | This file | — |
| `todo.md` | Task tracker + session log + known issues | — |
| `1792500018425-es-cekek-mvp-plan.md` | MVP design doc: formulas, tuning table, 5 implementer decisions, validation plan | Do not edit casually; mirror task checkboxes into `todo.md` |

### 3.2 `src/autoload/` — global singletons

| File | Purpose | Key API |
|---|---|---|
| `InputSetup.gd` | Builds the InputMap in code so desktop + mobile share action names | `_bind(action, keys…)`; actions: `move_forward/back/left/right`, `interact`, `travel`, `ui_accept`, `pour`, `add_water`, `stir`, `add_ice`, `add_straw`, `serve`, `run` |
| `Audio.gd` | Procedural SFX + ambient music, **NO external assets** — every sound is synthesised at runtime | `play(id: StringName)`, `sfx_ids() -> Array[StringName]`, `set_enabled(bool)`, `is_enabled()`, `start_ambient()`, `stop_ambient()`; constants `POOL_SIZE 8`, `SAMPLE_RATE 44100`; 10 ids: `pour`, `water`, `stir`, `ice`, `straw`, `cash`, `complain`, `build`, `serve`, `ui`; state `last_played`, `play_log` (last 64), `play_count`; private `_pool` (8 `AudioStreamPlayer`), `_cache` (stream per id), `_ambient_player`, `_make_stream(sampler, seconds)`, `_tone(freq, sec, vol, decay)`, `_noise(sec, vol, decay)`, `_make_sfx(id)`, `_stream_for(id)` |
| `Catalog.gd` | Loads all `.tres` data once; the single source of truth for locations/brands/tools | `locations`, `brands`, `tools`; `brand_by_id()`, `tool_by_id()`, `location_by_id()`; `startup_tools()`, `shop_tools()`, `all_tools()`, `available_on_day(day)`; private `_load_tools(paths) -> Array[Tool]` (typed-array helper) |
| `Inventory.gd` | Player's wallet + stock + owned tools | `money` (setter emits `money_changed`), `sachet_stock`, `ice_stock`, `owned_tools`; `add/remove_money`, `can_afford`, `deduct`, `add_sachets`, `consume_sachet`, `consume_ice`, `add_ice`, `has_tool`, `tool_in_slot`, `install_tool` (replaces same slot), `buy_tool`, `total_quality_mod`, `total_ice_capacity`, `can_make_bag`, `try_consume` (the real consume-on-build), `restock_sachets`, `restock_ice`, `grant_startup`; signals `stock_changed`, `money_changed`, `tools_changed` |
| `TimeOfDay.gd` | 3-minute day clock; drives the day bar **and the real day/night lighting** (sun angle/energy/colour + sky + ambient + fog) | `DAY_SECONDS = 180.0`, `SUNSET_RATIO = 0.9` (0→0.9 daylight, 0.9→1.0 night); `start_day(day)`, `stop()`, `elapsed_seconds()`, `end_day_manual()`, `is_daytime()`; signals `day_advanced`, `day_ended`, `time_tick(elapsed, normalized)`; **refs filled by `Main.gd`**: `sun_light` (DirectionalLight3D), `environment` (WorldEnvironment); **lighting API**: `apply_lighting(norm)`, `set_sun_tint(color)`; `sun_tint`; colours `day_color`, `dusk_color`, `night_color`, `night_light_color`, `day_sky_top/horizon`, `dusk_sky_horizon`, `night_sky_top/horizon`; private `_update_lighting(norm)`, `_sun_height(norm)`, `_sun_angle(norm)`, `_sun_energy(norm)`, `_light_color(norm)`, `_ambient_color(norm)` |
| `UILayer.gd` | All UI: HUD, prep panel, shop panel, day-end, travel picker, order queue | signals `interact_pressed`, `travel_requested(id)`, `day_end_continue`, `prep_action(action, value)`, `shop_action(action, value)`; `ACTION_*` / `SHOP_ACTION_*` constants (incl. `ACTION_PRICE_SET`, `PRICE_STEP 500`); `update_hud()`, `show_order()`, `show_complain()`, `show_loading()`, `show_error()`, `set_locations()`, `open/close_location_picker()`, `show_prep_panel()`, `is_prep_panel_open()`, `update_prep(data)`, `show_day_end(recap)`, `open/close_shop()`, `is_shop_panel_open()`, `buy_tool_at(i)`, `refresh_shop()`; **order queue**: `refresh_order_queue()`, `waiting_customers() -> Array[Customer]`; private `_build_order_queue()`, `_update_price_slider(data, has_bag)`, `_on_price_slider_changed(value)`, `_format_day_end_detail(recap)`, `_location_display_name(id)`; `move_vector` (joystick output) + **`set_move_vector(v: Vector2)`** (dipakai `VirtualJoystick` untuk memublikasikan vektor gerak — Task 11c) |
| `LocationManager.gd` | Loads/unloads location scenes under `Main/WorldRoot` | `available_locations`, `current_location`, `current_root`; `set_locations()`, `load_location(world_root, def)`, `travel_to(id)`, `has_location()`, `get_location()`, `unlock_location()`; signals `location_changed`, `load_started`, `load_finished` |
| `Economy.gd` | Day accounting, per-location rent, day-end recap, unlock reporting | `current_day`, `day_revenue`, `day_expenses`, `total_profit`, `completed_sales`, `last_recap`; `record_sale(brand_id, location_id, revenue)`, `add_expense()`, `charge_rent(location_id)` (once/day/location), `rent_by_location()`, `end_day()`, `new_unlocks_for_day(day)`; signals `day_started(day)`, `day_completed(recap)` |

### 3.3 `src/entities/` — actors

| File | Purpose | Key API |
|---|---|---|
| `Player.gd` | `CharacterBody3D`, ROAM/AT_STAND state machine, WASD + joystick movement, camera follow | `state`, `stand_snap_distance`; `_read_move_input()`, `_interact()`, `release_stand()`; group `"player"`; constants `WALK_SPEED 4.0`, `RUN_SPEED 7.0`, `ACCELERATION 14.0`, `FRICTION 16.0` |
| `Customer.gd` | One customer: walks, orders, gets annoyed, evaluates the serve | `order_brand`, `price_tolerance`, `annoyance_level`, `state` (ARRIVING/WAITING/SERVED/LEAVING), `is_seated`, `slot_index`, `annoyance_rate`; `setup(brand, rate)`, `add_annoyance(n)`, `evaluate_serve(bag) -> Dictionary`, `leave(exit_point)`; signals `complain(line, annoyance)`, `served(result)`, `left_the_stand`; constants `TIP_MULTIPLIER 0.4`, `PRICE_COMPLAIN_AT 1.5`, `ANNOYANCE_MAX_WAIT 45.0`, `ANNOYANCE_TIERS [0.30,0.60,0.85,1.00]`, `COMPLAIN_LINES`; group `"customer"`; **3D feedback**: `body`/`head`/`bubble` nodes, `BUBBLE_TIME 2.4`, `BODY_COLOR`, `BODY_ANGRY_COLOR`, `update_feedback(delta)`, `target_crouch() -> float`, `apply_pose(crouch)`, `show_bubble(line)`, `hide_bubble()`, `_on_complain(line, annoyance)` |
| `CustomerSpawner.gd` | Spawns customers, assigns seat vs queue slot, pauses at capacity | `location_def`, `stand`, `brands`, `customers`; `setup(def, stand, brands)`, `spawn_interval()`, `try_spawn()`, `forget(customer)`, `waiting_count()`, `next_customer()`, `clear_customers()`; `base_spawn_interval 9.0` |
| `Location.gd` | Runtime script for every location scene | `location_def`, `spawn_offset`; `initialize(def)`, `stand_spawn_position()`, `_apply_palette()` (→ `TimeOfDay.set_sun_tint(accent)`), `_apply_props()`; children `StandSlot/Stand`, `CustomerSpawner`, `Props`, `Ground` |

### 3.4 `src/resources/` — data classes

| File | Purpose | Key API |
|---|---|---|
| `Bag.gd` | Runtime drink being built/offered | `portions`, `ice_amount`, `prep_quality`, `sell_price`, `has_straw`; `cost()`, `fair_price_min()`, `fair_price_max()`, `recommended_price()`, `has_brand()`, `is_empty()`, `primary_brand()`; constants `MAX_SPOON_ICE 8`, `ICE_COST_PER_SPOON 0.2`, `FAIR_PROFIT_FLOOR 1.10`, `FAIR_PROFIT_MAX 2.0`, `RECOMMENDED_MARKUP 1.35` |
| `SachetPortion.gd` | One poured sachet inside a Bag | `brand`, `volume` |
| `SachetBrand.gd` | A brand definition | `id`, `display_name`, `base_cost`, `price_tier` (1000/2000/5000), `base_quality`, `sweetness`, `rarity`, `color_tint`, `icon`, `description` |
| `Tool.gd` | A stand tool/upgrade | `slot` (table/hook/water/cooler/mixer), `id`, `display_name`, `cost`, `quality_mod`, `capacity_mod`, `unlock_day`, `is_upgrade`, `icon`, `description` |
| `LocationDef.gd` | A location definition | `id`, `display_name`, `scene_path`, `rent_cost`, `foot_traffic`, `seats`, `max_queue`, `annoyance_rate`, `color_palette`, `description` |

### 3.5 `src/stand/` — the stand

| File | Purpose | Key API |
|---|---|---|
| `Stand.gd` | Hub of the prep/serve loop: counter, equipment, prep station, seats, queue, serve transaction | `current_bag` (**property with a setter** → the 3D bag on the counter is always in sync), `spawner`; `set_spawner()`, `seat_positions()`, `queue_positions()`, `service_position()`, `offer_bag(bag)`, `take_bag()`, `serve_to(customer, bag)`, `serve_offered_to(customer)`, `snapshot() -> Dictionary` (incl. `price`, `cost`, `fair_min`, `fair_max`, `recommended`, `quality`), `interact_at_stand()`, `close_prep()`, `_on_prep_action(action, value)` (routes `ACTION_PRICE_INC/DEC/SET`), `_adjust_price(delta)`, `_set_price(value)` (never below `Bag.cost()`), `_do_serve()`; signals `served`, `bag_offered`, `prep_changed`; **3D bag**: `BAG_QUALITY_GOOD 60`, nodes `bag_visual`/`bag_shell`/`bag_liquid`/`bag_straw`, private `_setup_bag_materials()`, `_refresh_bag_visual()`, `_set_bag_material(mesh, mat)`; **SFX (Task 12)**: `_wire_sfx()`, `_connect_sfx(sig, sfx_id)`, `_on_prep_sfx(sfx_id)`, `_on_bag_built(bag)` → `Audio.play()`; **PENTING (Task 12f)**: `seat_positions()` / `queue_positions()` mengambil **SEMUA anak** `Seats`/`Queue` — jadi anak-anak itu HARUS berupa mesh (kursi/bangku Kenney), bukan marker `Node3D` terpisah, kalau tidak jumlah kursi & antrean jadi dobel |
| `StandEquipment.gd` | Slot-based mirror of `Inventory.owned_tools` | `tools`; `refresh_from_inventory()`, `tool_in_slot(slot)`, `ice_capacity()` (reads the **cooler** slot only), `quality_mod()` (multiplies), `has_tool()`, `install(tool)` (replaces same slot), `slot_ids()`; signal `equipment_changed` |
| `PrepStation.gd` | The build pipeline: pour → water → stir → ice → straw → Bag | `rack`, `state`, `selected_brand`, `volume`, `has_water`, `has_stir`, `ice_amount`, `has_straw`; `set_equipment()`, `set_rack()`, `ice_capacity()`, `tool_quality_mod()`, `open_build()`, `reset()`, `select_brand()`, `pour(amount)`, `add_volume()`, `add_water()`, `stir()`, `add_ice(spoons)`, `add_straw()`, `step_score()`, `compute_prep_quality()`, `estimated_cost()`, `can_build()`, `build_bag()`, `discard_bag()`, `snapshot()`; weights `W_VOLUME .25 / W_WATER .20 / W_STIR .20 / W_ICE .25 / W_STRAW .10`; **SFX signals (Task 12)**: `pour_done`, `water_added`, `stirred`, `ice_added`, `straw_added` (all argument-free) |

### 3.6 `src/ui/` — UI

| File | Purpose | Key API |
|---|---|---|
| `UILayer.tscn` | All UI nodes. Loaded at runtime by `UILayer.gd` into a `CanvasLayer` | see node tree §5 |
| `VirtualJoystick.gd` | `Control` joystick (bottom-left) that publishes a move vector | `radius 110.0`, `dead_zone 0.12`; `_publish()` → cari node `UILayer` di rantai parent lalu panggil `set_move_vector()` (**sudah diperbaiki** — bug lama: method itu tidak pernah ada, jadi vektor tidak pernah sampai ke `Player`); `_find_ui_layer()` |

### 3.7 `tests/`

| File | Purpose |
|---|---|
| `runtime_test.gd` | The whole test suite: **246 assertions** covering catalog, inventory, prep, serve, customers, economy, shop, day cycle, order queue / price slider / day-end detail (Task 9), the day/night lighting (Task 4-L), the 3D feedback (Task 12: bag mesh, brand tint, complaint bubble, annoyance pose), the procedural SFX (Task 12: 10 PCM streams, cache, pool, ambient loop, and the event→sound wiring), the **virtual joystick** (Task 11: joystick benar-benar mempublikasikan `UILayer.move_vector` saat digeser) and the **asset pipeline** (Task 12c–12f: `Counter` = StaticBody3D + collision shape valid, 3 kursi + 5 slot antrean, mesh stand memakai GLB Kenney). Also boots the real game scene. |
| `runtime_test.tscn` | Harness scene (`extends Node`). **Run this, not `--script`.** |

### 3.8 `data/` — the actual values

| File | Values |
|---|---|
| `locations/pasar.tres` | rent 30, busiest, 3 seats, 5 queue |
| `locations/sekolah.tres` | rent 20, medium |
| `locations/rumah.tres` | rent 15, quietest |
| `brands/tejus.tres` | 1k tier → `base_quality 0.35` |
| `brands/marimas.tres` | 2k tier → `base_quality 0.60` |
| `brands/jasjus.tres` | 2k tier |
| `brands/frenta.tres` | 5k tier → `base_quality 0.85` |
| `tools/table.tres` | startup, slot `table`, `quality_mod 1.0` |
| `tools/sachet_hook.tres` | startup, slot `hook` |
| `tools/water_dispenser.tres` | startup, slot `water` |
| `tools/ice_cooler_small.tres` | startup, slot `cooler`, `capacity_mod 8` |
| `tools/ice_cooler_large.tres` | shop, slot `cooler`, `capacity_mod 16`, `quality_mod 1.2`, `unlock_day 2` |
| `tools/mixer.tres` | shop, slot `mixer`, `quality_mod > 1.0`, `unlock_day 3` |

### 3.9 `src/` — entry point

| File | Purpose | Key API |
|---|---|---|
| `Main.gd` | Entry scene script: boot, autoload wiring, day cycle, travel | `world_root`, `player`, `sun` (DirectionalLight3D), `world_environment` (WorldEnvironment); `_setup_inventory()`, `_wire_signals()`, `_on_day_started()`, `_on_day_ended()`, `_on_day_end_continue()`; **hands `sun` + `world_environment` to `TimeOfDay`** in `_ready()` |
| `Main.tscn` | Entry scene: `WorldRoot` + `Player` + `WorldEnvironment` + `Sun` | `Env_main` (Environment) → `Sky_res` (**`Sky` resource**) → `Sky_mat` (ProceduralSkyMaterial) |

---

## 4. Data Flow

### 4.1 One sale

```
CustomerSpawner.try_spawn()
  └─ Customer.setup(brand, rate)  →  UILayer.show_order(brand)      [callout]
Player at stand → Stand.interact_at_stand() → UILayer.show_prep_panel(true)
UILayer prep_action → Stand._on_prep_action → PrepStation.pour/water/stir/ice/straw
PrepStation.build_bag()
  └─ Inventory.try_consume(brand, spoons)   ← INGREDIENTS CONSUMED HERE (Decision #1)
  └─ Bag{portions, ice_amount, prep_quality, sell_price}
  └─ Stand.offer_bag(bag)
Player sets price: UILayer ACTION_PRICE_INC/DEC/SET → Stand._adjust_price / sell_price
Player serves: Stand._do_serve() → Stand.serve_offered_to(next_customer)
  └─ Customer.evaluate_serve(bag)
       ├─ wrong brand → no pay, bag wasted, annoyance +0.2  (Decision #2)
       └─ accepted    → tip = satisfaction*0.4*price (0 if >1.5× fair_max)
  └─ Inventory.add_money(paid) → Economy.record_sale(brand_id, location_id, paid)
```

### 4.2 One day

```
Economy.day_started(day) → Main._on_day_started → TimeOfDay.start_day(day)
   └─ Inventory.add_ice(STARTING_ICE) → UILayer.update_hud + refresh_shop
TimeOfDay._process → time_tick(elapsed, normalized) → UILayer._on_time_tick (day bar)
TimeOfDay._end_current_day → day_ended → Main._on_day_ended → Economy.end_day()
   └─ charges rent for every traded location (once each)
   └─ builds recap: day, revenue, expenses, profit, best_brand, sales,
                    location_revenue, brand_revenue, location_profit,
                    rent_by_location, locations_used, new_unlocks
   └─ emits day_completed(recap) → Main → UILayer.show_day_end(recap)
Player taps Continue → UILayer.day_end_continue → Main._on_day_end_continue → Economy.start_next_day()
```

---

## 5. Scene Node Trees

### `src/Main.tscn`
```
Main (Node3D, Main.gd)
├── WorldRoot (Node3D)          ← LocationManager swaps Location scenes in/out here
├── Player (instance Player.tscn)
├── WorldEnvironment            ← env "Env_main" → Sky_res (Sky) → Sky_mat (ProceduralSkyMaterial)
└── Sun (DirectionalLight3D, group "sun")   ← handed to TimeOfDay.sun_light
```

### `src/ui/UILayer.tscn`
```
UILayer (Control)
├── HUD (Control)
│   ├── Money (Label)      "Rp 0"
│   ├── Day (Label)        "Hari 1"
│   └── DayBar (ProgressBar)  max_value 1.0, show_percentage false
├── OrderCallout (Control)
│   └── Message (Label)    "Bang mau es Tejus!"
├── OrderQueue (VBoxContainer)      ← UILayer._order_queue
│   ├── Title (Label)      "Antrian: 0 orang"  ← UILayer._order_queue_label
│   └── Rows (VBoxContainer)         ← UILayer._order_rows_box (one Label per waiting customer)
├── Overlay (Control)
│   ├── Loading (Label)
│   └── Error (Label)
├── TravelPanel (Control)
│   ├── Background (ColorRect)
│   ├── List (VBoxContainer) → Title (Label)
│   └── Close (Button)
├── DayEnd (Control)
│   ├── Background (ColorRect)
│   └── Panel (MarginContainer)
│       └── Column (VBoxContainer)
│           ├── Title (Label)   "Rekap Hari"
│           ├── Summary (Label) ← UILayer._day_end_label
│           ├── Detail (Label)  ← UILayer._day_end_detail (profit per location, rent, unlocks)
│           └── Continue (Button, 56dp)
├── TouchButtons (Control)
│   ├── Interact (Button)
│   ├── Travel (Button)
│   └── Shop (Button)         "TOKO"
└── VirtualJoystick (Control)
```
> The **prep panel** and the **shop panel** are NOT in the scene — they are built in code by
> `UILayer._build_prep_panel()` / `_build_shop_panel()` and added to `_ui_root` as
> `PrepPanel` / `ShopPanel`.

### `src/entities/Location.tscn`
```
Location (Node3D, Location.gd)
├── StandSlot (Node3D)
│   └── Stand (instance Stand.tscn)
├── CustomerSpawner (instance CustomerSpawner.tscn)
├── Props (Node3D) → Prop_1, Prop_2 (MeshInstance3D, tinted by palette)
└── Ground (StaticBody3D) → GroundShape, GroundMesh
```

### `src/stand/Stand.tscn`
```
Stand (Node3D, Stand.gd)
├── Counter (StaticBody3D, group "stand")
│   ├── CounterMesh   ← instance furniture/table.glb  pos (-1.177, 0, 0.626)  scale 2.8
│   └── CounterShape  (CollisionShape3D)  BoxShape3D 2.36 × 0.92 × 1.25  pos (0, 0.46, 0)
├── StandEquipment (Node, StandEquipment.gd)
├── PrepStation (instance PrepStation.tscn)  pos (-0.6, 0.92, 0)
├── CashRegister  ← instance furniture/computerScreen.glb  pos (0.85, 0.92, 0.05)  yaw 180°  scale 1.2
├── Seats (Node3D) → Chair_1..3  ← instance furniture/chair.glb  pos (-1.0 / 0.15 / 1.3, 0, 1.78)  yaw 180°  scale 1.5
├── Queue (Node3D) → Bench_1..5  ← instance furniture/bench.glb  pos (2.9, 0, 0.9/1.7/2.5/3.3/4.1)  yaw 180°  scale 1.5
└── BagVisual (Node3D)          ← Task 12: the 3D bag on the counter
    ├── Shell (MeshInstance3D)   translucent plastic
    ├── Liquid (MeshInstance3D)  tinted by brand, scale.y = volume
    └── Straw (MeshInstance3D)   visible = bag.has_straw
```
> **Task 12f**: tidak ada lagi marker `Seat_1..3` / `Queue_1..5` — kursinya sendiri yang jadi marker,
> karena `Stand.seat_positions()` / `queue_positions()` mengambil semua anak `Seats`/`Queue`.
> **PENTING**: `CounterShape` WAJIB punya `type="CollisionShape3D"`. Tanpa itu Godot menjadikannya
> turunan `StaticBody3D` (tipe parent) → `shape` gagal assignment diam-diam → `Counter` tanpa collision
> → `Player.InteractArea` tidak pernah mendeteksi stand → **panel prep tidak bisa dibuka saat main**.

### `src/stand/PrepStation.tscn`
```
PrepStation (Node3D, PrepStation.gd)
├── Rack (Node3D)  pos (0, 0, -0.22)
│   └── CuttingBoard  ← instance food/cutting-board.glb  pos (0.05, 0, 0)  scale (1, 1, 0.45)
├── IceCooler      ← instance food/barrel.glb      pos (-0.42, 0, -0.2)  scale (0.45, 0.3, 0.45)
├── WaterDispenser ← instance food/carton.glb      pos (0.48, 0, -0.2)   scale (0.9, 0.4, 0.9)
└── StrawHolder    ← instance food/soda-can.glb     pos (0.75, 0, -0.18)  scale (0.8, 0.8, 0.8)
```

### `src/entities/Player.tscn`
```
Player (CharacterBody3D, Player.gd)
├── CollisionShape3D
├── Body (MeshInstance3D) → Head (MeshInstance3D)
├── CameraRig (Node3D) → Camera3D
└── InteractArea (Area3D) → InteractShape
```

### `src/entities/Customer.tscn`
```
Customer (Node3D, Customer.gd)
├── Body (MeshInstance3D)   scale.y = crouch, colour = annoyed
├── Head (MeshInstance3D)   position.y = crouch, rotation.x = annoyed
└── Bubble (Label3D)       billboard, text = complaint line
```

### `src/entities/CustomerSpawner.tscn`
```
CustomerSpawner (Node3D, CustomerSpawner.gd) → Marker (MeshInstance3D)
```

---

## 6. Autoload Order (load-bearing)

```
InputSetup      → no deps
Audio           → no deps
Catalog         → no deps
Inventory       → Catalog
TimeOfDay       → no deps
UILayer         → no deps
LocationManager → UILayer
Economy         → LocationManager, Inventory, UILayer
```

A script may **only** reference an autoload registered **before** it. To reach a later one, fetch it
from the tree: `get_tree().root.get_node_or_null("Economy")` (see `UILayer._current_day()`).

---

## 7. Implementer Decisions (MUST NOT change silently)

1. **Consumption timing**: sachet + ice consumed when the Bag is **built**, not when sold. Wrong-brand refusal still wastes them.
2. **Overpricing**: customer never refuses on price; >1.5× fair_max → "Mahal amat!" + zero tip but still pays. Refuse **only** on wrong brand.
3. **Queue cap**: seats=3 + max_queue=5; beyond that spawns pause.
4. **Annoyance never expels**: lever is `annoyance_rate` per location.
5. **Day length lever**: `TimeOfDay.DAY_SECONDS` (180) — never shorten by reducing customer patience.

---

## 8. Tuning Parameters

| Parameter | Location | Default |
|---|---|---|
| `TimeOfDay.DAY_SECONDS` | TimeOfDay.gd | 180 |
| `ICE_COST_PER_SPOON` | Bag.gd | 0.2 |
| `MAX_SPOON_ICE` | Bag.gd / PrepStation.gd | 8 |
| `FAIR_PROFIT_FLOOR/MAX` (× cost) | Bag.gd | 1.10 / 2.0 |
| `RECOMMENDED_MARKUP` | Bag.gd | 1.35 |
| `TIP_MULTIPLIER` | Customer.gd | 0.4 |
| `PRICE_COMPLAIN_AT` (× cost) | Customer.gd | 1.5 |
| `ANNOYANCE_MAX_WAIT` (s) | Customer.gd | ~45 (scales by location) |
| `ANNOYANCE_TIERS` | Customer.gd | 0.30 / 0.60 / 0.85 / 1.00 |
| `SEATS_PER_STAND` | LocationDef | 3 |
| `MAX_QUEUE_PER_STAND` | LocationDef | 5 |
| `LOCATION_RENT_PER_DAY` | LocationDef | Pasar 30 / Sekolah 20 / Rumah 15 |
| `CUSTOMER_PRICE_TOLERANCE` | Customer.gd | 0.7–0.85 × fair_max |
| `SACHET_BASE_QUALITY` (1k/2k/5k) | SachetBrand | 0.35 / 0.60 / 0.85 |
| `STARTUP_TOOLS` | Catalog / StandEquipment | table, sachet_hook, water_dispenser, ice_cooler_small |
| `ICE_CAPACITY_SMALL` (spoons) | Tool/ice_cooler_small | 8 (large = 16) |
| `TOOL_QUALITY_MOD_BASE` (startup) | StandEquipment | 1.0 (multiplies with upgrades) |
| `STARTING_MONEY` / `STARTING_ICE` / `STARTING_SACHETS_PER_BRAND` | Main.gd | 50000 / 40 / 20 |
| `PRICE_STEP` | UILayer.gd | 500.0 |

---

## 9. Godot Gotchas (learned the hard way — do not rediscover)

1. **`--script` mode compiles the global class cache before autoload registration** → `Identifier not found: Catalog`. Fix: run tests as a **scene** (`res://tests/runtime_test.tscn`).
2. **`Array.map()` returns an untyped Array** → cannot be passed to an `Array[Tool]` parameter ("does not have the same element type"). Build typed arrays in an explicit loop (`Catalog._load_tools`).
3. **`Array.count(callable)` errors on typed arrays** ("Attempted to count a variable of type 'Callable' into a TypedArray"). Use an explicit counter loop.
4. **`Array.duplicate()` on a typed array can return an untyped Array** — use explicit `append` loops when the target is typed.
5. **`Control.set_anchors_preset(PRESET_CENTER)` does NOT center by itself** — set explicit offsets.
6. **Autoload order** — a script may only reference autoloads registered before it.
7. **`apply_diff` needs exactly 7 `<`** for the `<<<<<<< SEARCH` marker. 8 fails with "Special marker found".
8. **Do not `queue_free()` a button inside its own `pressed` signal** — the button dies mid-emit. Use `call_deferred` (see `UILayer.refresh_shop()`).
9. **A `.tscn` cannot contain an inline resource** — `theme_override_styles/fill = StyleBoxFlat` is a parse error ("Parse error. [Resource file res://src/ui/UILayer.tscn:48]"). Use a `[sub_resource]` block and reference it.
10. **`queue_free()` is deferred** — the node is still a child until the end of the frame, so `get_child_count()` still counts it. Call `remove_child()` first when the count matters (see `UILayer.refresh_order_queue()`).
11. **`Range` (HSlider) snaps the value relative to `min_value`** (`min + round((v - min) / step) * step`). A coarse step therefore makes the slider disagree with the real price. Use `step = 0.01` when the value must match exactly.
12. **Godot 4 `Environment` has `fog_light_energy`, NOT `fog_light_intensity`** — the latter throws "Invalid assignment of property or key 'fog_light_intensity'" every frame.
13. **`Environment.sky` must be a `Sky` resource**, not a `ProceduralSkyMaterial`. Wrap the material: `[sub_resource type="Sky" id="Sky_res"] sky_material = SubResource("Sky_mat")` and point `Environment.sky` at `Sky_res` — otherwise the sky silently never renders.
14. **Writing `min_value`/`max_value` on a `Range` also moves its `value`** — put any "I am syncing, do not react" guard *before* the first write, otherwise the control emits its own change signal and overwrites the data it was displaying.
15. **`Color.get_saturation()` does not exist in Godot 4** — use the `.s` property instead.
16. **A `var` needs an explicit `set(value):` block to intercept assignments** — use it when a plain field must trigger side effects (e.g. `Stand.current_bag` refreshing the 3D bag).
17. **`Label3D` needs `billboard = 1` and `no_depth_test = true`** or it never faces the camera / gets hidden behind geometry.
18. **A `material_override` sub-resource in a `.tscn` is SHARED between instances** — `duplicate()` it in `_ready()` before mutating it, or every customer turns red when one gets annoyed.
19. **A node in a `.tscn` WITHOUT `type=` silently inherits its parent's type** — e.g. `CounterShape` tanpa `type="CollisionShape3D"` jadi `StaticBody3D`; assignment `shape = SubResource(...)` **gagal tanpa error**, dan node itu hilang dari tree karena "was modified from inside an instance, but it has vanished". **Selalu tulis `type=`** untuk node non-instance.
20. **GLB Kenney menghadap arah +Z** (sandaran kursi di -Z) — sama dengan mini-characters, jadi mesh di game harus **di-yaw 180°**. Perhatikan: AABB beberapa GLB **tidak simetris** (mis. `chair.glb` x=[0..0.2]), jadi yaw 180° **membalik offset X** → posisi harus dikoreksi.
21. **Export Android: pakai `--export-debug`, bukan `--export-release`** — `--export-release` mencari *release* keystore (tidak ada di preset) → "Could not find release keystore, unable to export." APK sempat tertulis tapi **tidak signed** (`.idsig` juga tidak tergenerate). `--export-debug` memakai debug keystore dari `editor_settings-4.7.tres` → signed + `.idsig` tergenerate.

---

## 10. Task Progress

| # | Task | Status |
|---|------|--------|
| 1 | Install Godot 4.x + Android templates; project scaffolding | ✅ Done |
| 2 | Import CC0 assets; Location.tscn template | ✅ Done (`assets/kenney/` sudah terisi 197 GLB) |
| 3 | Player.tscn: CharacterBody3D + ROAM/AT_STAND state machine | ✅ Done |
| 4 | LocationManager singleton + Pasar location scene | ✅ Done |
| 4-L | Day/night lighting: `TimeOfDay` drives the real sun + sky + ambient + fog (tracked in `todo.md` as the lighting task) | ✅ Done (141/141 green, boot OK) |
| 12a | 3D feedback: bag mesh on the counter (brand tint, volume, quality), customer complaint bubble, annoyance pose | ✅ Done (178/178 green, boot OK) |
| 12b | Procedural SFX autoload (`Audio`): 10 synthesised sounds + ambient music loop, no external assets | ✅ Done (225/225 green, boot OK) |
| 12c | Pipeline asset Kenney CC0: unduh 6 pack, subset 197 GLB + 4 colormap, import Godot | ✅ Done (197 GLB, 10,6 MB) |
| 12d | Karakter: player + pelanggan pakai GLB mini-characters (ganti box primitif) | ✅ Done (239/239 green, boot OK) |
| 12e | Lokasi: Pasar / Sekolah / Rumah dibangun dari mesh Kenney (gedung, tenda, jalan, rumah, pohon, pagar) | ✅ Done (239/239 green, boot OK) |
| 12f | Propsi stand: meja konter, 3 kursi, 5 bangku antrean, kasir, tack prep (food pack) | ✅ Done (246/246 green, boot OK) |
| 5 | SachetBrand resource + 4 brands; Tool resource + startup set; StandEquipment + Inventory | ✅ Done |
| 6 | Stand.tscn + PrepStation.tscn; prep pipeline → Bag with prep_quality | ✅ Done |
| 7 | Customer scene + spawner: NavMesh walk, order, annoyance, serve | ✅ Done |
| 8 | Economy + TimeOfDay singletons: rent, recap, unlocks | ✅ Done (109/109 green) |
| 9 | UILayer: price slider, day bar, order queue, shop panel, richer recap | ✅ Done (127/127 green, boot OK) |
| 10 | Sekolah + Rumah locations; travel wiring | ✅ Done |
| 11a | Export presets (`export_presets.cfg`: Windows/Linux/macOS/Android) + setelan Android | ✅ Done (4 preset ter-parse & diekspor headless) |
| 11b | Export template Godot 4.7.2 + build artifacts (Windows/Linux/macOS/Android) | ✅ Done (semua 4 target ter-build; .exe terverifikasi boot bersih) |
| 11c | Perbaikan bug virtual joystick (`UILayer.set_move_vector` tidak pernah ada) | ✅ Done (233/233 hijau, boot OK) |
| 11 | Android QA: install APK di perangkat asli + uji joystick / prep / UI | ⏳ Pending (butuh perangkat Android — `adb devices` kosong) |
| 12 | Polish: SFX ✅, complain vocals, music loop ✅, VFX, location colors | ⏳ Pending (SFX + music done; visual 3D ✅) |

---

## 11. Test Status

- **Suite**: `tests/runtime_test.gd` run as a scene (`res://tests/runtime_test.tscn`)
- **Last known result**: **246/246 checks pass, 0 fail** + "game booted without errors"
  (`scripts\run_tests.cmd --boot`, 2026-10-21, after the Kenney stand-props pass)
- **Command**: `scripts\run_tests.cmd`  (add `--boot` to also boot the real game headless)
- The suite covers the full loop: catalog → prep → customer → serve → economy → day cycle,
  plus the Task 8 shop/rent, the Task 9 order queue / price slider / day-end detail,
  the day/night lighting (sun energy/colour/angle, sky colours, per-location tint),
  the 3D feedback (bag visibility/tint/scale, complaint bubble, annoyance pose) and
  the procedural SFX (10 valid 16-bit PCM streams, stream cache, player pool, ambient
  loop, and every game event → the right sound id), the **virtual joystick**
  (joystick benar-benar mempublikasikan `UILayer.move_vector` saat digeser, dan
  vektor kembali nol saat dilepas) and the **asset pipeline** (Task 12c–12f: `Counter`
  bertipe `StaticBody3D` **dengan collision shape yang valid**, tepat 3 kursi + 5 slot
  antrean, dan mesh stand/rupa/prep memang GLB Kenney, bukan box primitif).
- Godot prints `WARNING: N ObjectDB instances were leaked at exit` in headless mode.
  The count is **non-deterministic** (27 / 43 / 61 across runs) and also occurs on the
  plain `--boot` run, so it comes from Godot's own shutdown ordering (deferred frees
  still pending), not from a fixed allocation in the game code. It does not affect the
  pass/fail count.
- **Export check (headless)**: `godot --headless --path . --export-release "<preset>" <out>` → **berhasil untuk 4 target**.
  **Pengecualian Android**: WAJIB `--export-debug` (lihat gotcha #21 — `--export-release` gagal signing
  karena tidak ada release keystore). Export template Godot 4.7.2 sudah terpasang di
  `%APPDATA%\Godot\export_templates\4.7.2.stable` (35 file, unduhan sekali saja ±1,28 GB).
  Artifacts hasil build (**setelah asset Kenney masuk, build di-ekspor ulang**):

  | Target | Output | Ukuran |
  |---|---|---|
  | Windows | `build/windows/EsCekek.exe` (+ `EsCekek.pck`) | 109,1 MB (exe) + **3,4 MB (pck)** |
  | Linux | `build/linux/EsCekek.x86_64` (+ `EsCekek.pck`) | 73,5 MB + **3,4 MB (pck)** |
  | macOS | `build/macos/EsCekek.zip` (universal) | 62,9 MB |
  | Android | `build/android/EsCekek.apk` (+ `.idsig`) | **89,8 MB** — `com.escekek.game`, minSdk 24, targetSdk 36, arm64-v8a/armeabi-v7a/x86_64, **signed (debug keystore)** |

  > `.pck` naik dari 181 KB → **3,4 MB** karena 197 mesh Kenney ikut ter-pack.
  > Verifikasi isi: `findstr /m /c:"assets/kenney" build\windows\EsCekek.pck` → ketemu.

- **Smoke test build**: `build\windows\EsCekek.exe --headless --quit-after 120` → boot bersih
  (hanya 2 ObjectDB leak, tanpa error script) — **diverifikasi ulang setelah re-export dengan asset Kenney**.
- **Android toolchain**: `export/android/java_sdk_path` (JDK 17) + `android_sdk_path` + debug keystore
  sudah diset di `%APPDATA%\Godot\editor_settings-4.7.tres`. `adb devices` → **tidak ada perangkat
  tersambung**, jadi QA di HP asli (joystick / prep / UI) belum bisa dilakukan.
- **Renderer di PC ini**: GPU (Intel HD Graphics) tidak mendukung D3D12/Vulkan, Godot otomatis
  turun ke **Compatibility (OpenGL 3.3 via ANGLE)** dan game tetap jalan tanpa script error.
  Untuk Android, `renderer/rendering_method.mobile="gl_compatibility"` dipaksa di `project.godot`.

---

## 12. Known Issues / Risks

| # | Issue | Where | Status |
|---|---|---|---|
| 1 | ~~Joystick mencari method `set_move_vector` yang tidak pernah ada~~ → **DIPERBAIKI**: `UILayer.set_move_vector(v)` ditambahkan dan `_publish()` memanggilnya. Dulu vektor gerak sentuh tidak pernah sampai ke `Player` (game di HP tidak bisa digerakkan) | `src/ui/VirtualJoystick.gd`, `src/autoload/UILayer.gd` | 🟢 fixed (233/233) |
| 2 | The price slider snaps its value to `min_value + n * step`; the step is therefore `0.01` so the slider always shows the exact price that is charged | `src/autoload/UILayer.gd` | 🟢 documented |
| 3 | The day/night lighting is only verified by headless assertions (energy / colour / angle / sky). The *visual* result has not been eyeballed in the editor yet — colours may need a taste pass | `src/autoload/TimeOfDay.gd` | 🟡 open |
| 4 | The 3D feedback (bag mesh, bubble, pose) is only verified by headless assertions. The *visual* result has not been eyeballed in the editor yet — the bag size and the bubble font may need a taste pass | `src/stand/Stand.gd`, `src/entities/Customer.gd` | 🟡 open |
| 5 | ~~`assets/` hanya berisi `icon.png` — semua visual masih geometri primitif~~ → **SELESAI (Task 12c–12f)**: `assets/kenney/` kini berisi 197 GLB CC0 (mini-characters, commercial, suburban, roads, furniture, food) — karakter, lokasi, dan propsi stand semuanya mesh sungguhan. Audio tetap tanpa aset (SFX disintesis runtime) | `assets/kenney/` | 🟢 done |
| 6 | Export template Godot 4.7.2 **sudah terpasang** → 4 build (Windows/Linux/macOS/Android) **sudah ada** di `build/`. Tinggal QA di perangkat Android asli | project root / `%APPDATA%\Godot` | 🟢 done (lihat Task 11b) |
| 7 | `Economy.charge_rent()` uses `Inventory.remove_money()` which clamps at 0 — a player with $0 absorbs the loss silently | `Economy.gd` | 🟢 acceptable (documented failure mode) |
| 8 | The procedural SFX are only verified by headless assertions (the PCM data is valid 16-bit, the right event fires the right sound id). The *audible* result has not been listened to yet — the tones are placeholders and may need a taste pass | `src/autoload/Audio.gd` | 🟡 open |
| 9 | Godot prints `WARNING: N ObjectDB instances were leaked at exit` in headless mode. The count is non-deterministic (27 / 43 / 61 across runs) and also appears on the plain `--boot` run — it comes from Godot's shutdown ordering, not from a fixed game allocation | engine shutdown | 🟢 benign (documented) |
| 10 | GPU PC ini (Intel HD Graphics) tidak mendukung D3D12/Vulkan → Godot jatuh ke Compatibility/OpenGL. Scene sudah kompatibel (tidak ada feature khusus Forward+/Mobile yang dipakai), tapi game **belum pernah diEYE-balling** di editor sehingga kualitas visual & UI belum diverifikasi mata | `project.godot` (`renderer/rendering_method`) | 🟡 open |
| 11 | Joystick **sudah** menggerakkan pemain (bug diperbaiki + 8 asersi regresi baru), tetapi belum diverifikasi di layar sentuh sungguhan karena tidak ada perangkat Android tersambung via adb | `src/ui/VirtualJoystick.gd` | 🟡 open (hanya menunggu perangkat) |
| 12 | `build/` di-ignore Git → artefak build tidak ikut ter-commit (memang diameterkan; build ulang lewat `export_presets.cfg`) | `.gitignore` | 🟢 by design |
| 13 | **Bug collision tersembunyi di `Stand.tscn`**: `CounterShape` ditulis tanpa `type="CollisionShape3D"` → Godot menjadikannya turunan `StaticBody3D` (tipe parent), assignment `shape` gagal **tanpa error**, dan `Counter` berakhir **tanpa collision shape sama sekali** → `Player.InteractArea` tidak pernah mendeteksi stand → **panel prep tidak bisa dibuka saat main**. Unit test lama lolos karena memanggil `stand.interact_at_stand()` langsung, bukan lewat fisika. **Diperbaiki + asersi regresi baru** (Counter StaticBody3D, CounterShape valid, 3 kursi, 5 antrean, mesh Kenney) | `src/stand/Stand.tscn` | 🟢 fixed (246/246) |
| 14 | Export Android `--export-release` **gagal signing** ("Could not find release keystore") → APK sempat tertulis tapi **tidak signed** dan tidak menghasilkan `.idsig` baru. Fix: pakai `--export-debug` (debug keystore dari `editor_settings-4.7.tres`) | `export_presets.cfg`, `scripts/` | 🟢 fixed (APK 89,8 MB signed + `.idsig`) |
| 15 | Gaya visual **belum pernah dilihat mata** di editor — semua penempatan mesh Kenney diverifikasi **numerik** (AABB vertex-level: alas di y=0, properti di atas meja di y=0,920, kaki kursi/bangku di lantai) tapi belum di-eye-ball. Kemungkinan perlu taste pass (skala kursi/angkot, posisi kasir, kepadatan objek) | `src/stand/Stand.tscn`, `locations/*.tscn` | 🟡 open |
| 16 | Sebagian mesh Kenney memakai `baseColorFactor` (warna per-vertex), sebagian lagi merujuk `Textures/colormap.png` eksternal. 4 pack punya `colormap` (mini, commercial, suburban, food); `roads` & `furniture` tidak punya folder `Textures/` → 4 colormap, bukan 5 | `assets/kenney/*/Textures/` | 🟢 documented |
| 17 | Character/pelanggan pakai GLB mini-characters dengan `MODEL_SCALE 2.53` + `MODEL_YAW PI`; **pose kesal** (crouch) yang sebelumnya berupa `body.scale.y` mungkin perlu diselaraskan dengan tinggi model | `src/entities/KenneyCharacter.gd`, `src/entities/Customer.gd` | 🟡 open (perlu taste pass) |

---

## 13. Recent Changes (newest first)

### Latest — Task 12c–12f: asset Kenney CC0 masuk (karakter, lokasi, propsi stand) + re-export (2026-10-21)

1. **Task 12c — pipeline asset Kenney (CC0)**: `scripts/prepare_kenney_assets.ps1` mengunduh 6 pack resmi
   Kenney, mengambil subset yang dipakai, menyalin `Textures/colormap.png`, lalu memaksa re-import
   dengan menghapus `.glb.import`. Hasil: **`assets/kenney/` = 197 GLB (10,6 MB)** + 4 colormap
   (`mini` 12, `commercial` 25, `suburban` 39, `roads` 38, `furniture` 33, `food` 50 GLB).
   Semua dari pack **Mini Characters / City Kit Commercial / City Kit Suburban / City Kit Roads /
   Furniture Kit / Food Kit** — LICENSE CC0, satu gaya low-poly yang konsisten.
   Parameter import GLB diverifikasi: `nodes/apply_root_scale=true`, `nodes/root_scale=1.0`,
   `materials/extract=0` → skala authoring GLB terjaga 1:1, jadi `scale` di scene adalah satu-satunya
   knob penskalaan.
2. **Task 12d — karakter**: `src/entities/KenneyCharacter.gd` memuat 12 GLB mini-characters
   (`MODEL_SCALE 2.53`, `MODEL_YAW PI` — GLB menghadap +Z, game menghadap -Z) dan dipakai untuk
   player + pelanggan. Pose kesal & bubble keluhan tetap bekerja (246/246 hijau).
3. **Task 12e — lokasi**: `locations/pasar.tscn` / `sekolah.tscn` / `rumah.tscn` dibangun dari mesh
   Kenney (gedung + tenda + jalan di Pasar; sekolah + lapangan di Sekolah; rumah + pohon + pagar di
   Rumah) — tiap lokasi benar-benar berbeda, bukan lagi kotak-kotak.
4. **Task 12f — propsi stand**: `Stand.tscn` → meja konter (`furniture/table.glb`, scale 2,8),
   3 kursi (`furniture/chair.glb`, yaw 180°, scale 1,5), 5 bangku antrean (`furniture/bench.glb`),
   kasir (`furniture/computerScreen.glb`). `PrepStation.tscn` → talenan (`food/cutting-board.glb`),
   cooler es (`food/barrel.glb`), dispenser air (`food/carton.glb`), wadah sedotan (`food/soda-can.glb`).
   Marker `Seat_1..3` / `Queue_1..5` dihapus (kursinya sendiri yang jadi marker) supaya
   `seat_positions()` / `queue_positions()` tetap menghasilkan 3 dan 5.
   Penempatan diverifikasi **numerik** (AABB vertex-level): meja 0,915 m, semua properti di atas meja
   mulai y=0,920, kaki kursi/bangku di y=0.
5. **Bug collision tersembunyi ditemukan & diperbaiki**: `CounterShape` ditulis tanpa
   `type="CollisionShape3D"` → Godot menjadikannya turunan `StaticBody3D` (tipe parent), assignment
   `shape` **gagal tanpa error**, dan `Counter` berakhir **tanpa collision shape** →
   `Player.InteractArea` tidak pernah mendeteksi stand → **panel prep tidak bisa dibuka saat main**.
   Unit test lama lolos karena memanggil `stand.interact_at_stand()` langsung. Ditutup asersi regresi
   baru (Counter StaticBody3D, CounterShape valid, 3 kursi, 5 slot antrean, mesh Kenney) → **246/246 hijau, boot OK**.
6. **Re-export 4 build** (setelah asset Kenney masuk): Windows 109,1 MB + **pck 3,4 MB** (naik dari
   181 KB karena 197 mesh ikut ter-pack, `findstr /m /c:"assets/kenney"` → ketemu), Linux 73,5 MB,
   macOS zip 62,9 MB, Android APK **89,8 MB signed** (`.idsig` tergenerate).
   **Catatan penting**: Android harus `--export-debug` — `--export-release` gagal signing
   ("Could not find release keystore") karena preset tidak punya release keystore.
   `build\windows\EsCekek.exe --headless --quit-after 120` → boot bersih (hanya 2 ObjectDB leak).
7. **Housekeeping**: semua alat ukur sementara dihapus (`tools/check_stand.gd`, `tools/facing.gd`,
   `tools/inspect_assets.*`, `tools/inspect_pose.*`, `tools/loadtest.gd`, `tools/measure.*`,
   `scripts/run_layout.cmd`) → folder `tools/` kini kosong.

### Task 11b + 11c: export template, 4 build, fix joystick (2026-10-21)

1. **Export template terpasang + 4 build (Task 11b)**: `Godot_v4.7.2-stable_export_templates.tpz` (1,28 GB) diunduh, diekstrak, lalu 35 file template disalin ke `%APPDATA%\Godot\export_templates\4.7.2.stable`. Setelah itu export headless **berhasil untuk 4 target**:
   - `build/windows/EsCekek.exe` (109,1 MB) + `EsCekek.pck` (181 KB)
   - `build/linux/EsCekek.x86_64` (73,5 MB) + `EsCekek.pck` (181 KB)
   - `build/macos/EsCekek.zip` (59,9 MB, universal)
   - `build/android/EsCekek.apk` (86,5 MB) — `com.escekek.game`, minSdk 24, targetSdk 36, arm64-v8a/armeabi-v7a/x86_64

   Dua hambatan dipecahkan: (a) **ikon proyek** — Android menolak export tanpa ikon → `assets/icon.png` (256×256, digambar dengan System.Drawing) dibuat dan `config/icon="res://assets/icon.png"` diset di `project.godot`; (b) **Java SDK kosong** → `export/android/java_sdk_path` diset ke JDK 17 di `editor_settings-4.7.tres`, dan debug keystore dicopy ke `%APPDATA%\Godot\keystores\`. Verifikasi: `build\windows\EsCekek.exe --headless --quit-after 120` → boot bersih tanpa error.
2. **Bug virtual joystick diperbaiki (Task 11c)**: `VirtualJoystick._publish()` mencari method `set_move_vector` di rantai parent — method itu **tidak pernah ada** (UILayer hanya punya `var move_vector`), sehingga vektor gerak sentuh tidak pernah sampai ke `Player._read_move_input()`. Artinya **game di HP tidak bisa digerakkan sama sekali**. Perbaikan: `UILayer.set_move_vector(v: Vector2)` ditambahkan dan `_publish()` memanggilnya (dengan fallback `set("move_vector", v)`). Ditutup 8 asersi regresi baru → **233/233 hijau, boot OK**. Keempat build di-ekspor ulang setelah fix.

### Task 11a + dokumentasi (2026-10-21)

1. **Task 11a + dokumentasi (lengkap)**: `export_presets.cfg` dibuat untuk **Windows Desktop / Linux / macOS / Android** (output ke `build/`; `export_presets.cfg` kini tidak di-ignore Git). `project.godot` mendapat `config/version="1.0.0"` dan `renderer/rendering_method.mobile="gl_compatibility"` (Android dipaksa GLES3 agar HP tanpa Vulkan tetap jalan). Diverifikasi headless: preset terbaca benar, export **gagal hanya** karena export template 4.7.2 belum terpasang (`%APPDATA%\Godot\export_templates` kosong). `Readme.md` ditulis ulang (cara main, kontrol, cara test headless, cara export, daftar yang belum selesai) dan `todo.md`/plan disinkronkan. Suite tetap **225/225 hijau + boot OK**. Temuan baru: GPU PC ini (Intel HD Graphics) tidak mendukung D3D12/Vulkan → Godot otomatis memakai renderer **Compatibility/OpenGL via ANGLE** dan game tetap jalan normal tanpa script error.

### Riwayat sebelumnya

1. **Task 12 (procedural SFX, complete)**: new autoload `src/autoload/Audio.gd` — every sound is synthesised at runtime as a 16-bit `AudioStreamWAV` at 44.1 kHz, so the project needs **no external audio assets**. 10 sound ids (`pour`, `water`, `stir`, `ice`, `straw`, `cash`, `complain`, `build`, `serve`, `ui`), a pool of 8 `AudioStreamPlayer` so sounds can overlap, a per-id stream cache so the PCM is generated once, and a 2-second looping ambient drone. Wiring: `PrepStation` gained five argument-free signals (`pour_done`, `water_added`, `stirred`, `ice_added`, `straw_added`); `Stand._wire_sfx()` maps them to the sounds, `Stand.serve_to()` plays `cash` and `serve_offered_to()` plays `serve`; `Customer._on_complain()` plays `complain` (covering both the wrong-brand and the overprice path). Fixed a latent bug found while wiring: `bag_built` carries a `Bag` argument, so binding the sound id to it would have broken the handler signature — it got its own `_on_bag_built(bag)` handler. +47 assertions → **225/225 green, boot OK**.
2. **Task 12 (3D feedback, complete)**: `Stand.tscn` → `BagVisual` (Shell/Liquid/Straw) sitting on the counter — the liquid is tinted with `brand.color_tint`, fades toward grey as `prep_quality` drops below 60, turns paler with ice, and its height follows the poured volume; a straw appears when the bag has one. `Stand.current_bag` became a property with a setter so the 3D bag can never go stale. `Customer.tscn` → `Bubble` (a billboard `Label3D`) that appears on every `complain` signal and disappears after 2.4 s, plus an annoyance pose (body squats, head droops, body reddens) driven by `target_crouch()`. +37 assertions → **178/178 green, boot OK**.
3. **Day/night lighting (complete)**: `TimeOfDay` now owns the real lighting cycle — sun angle (rises at dawn, sets at `SUNSET_RATIO = 0.9`), energy (1.0 noon → 0.4 dusk → 0.12 moonlight), colour (warm dusk → bright day → blue night), sky top/horizon colours, ambient light and fog. `Main.gd` hands over the persistent `Sun` + `WorldEnvironment`; `Location._apply_palette()` supplies a per-location accent via `TimeOfDay.set_sun_tint()`. Fixed two latent bugs found by the new tests: `fog_light_intensity` → `fog_light_energy` (Godot 4 API name) and `Main.tscn` pointing `Environment.sky` at a `ProceduralSkyMaterial` instead of a `Sky` resource. +14 assertions → **141/141 green, boot OK**.
4. **Task 9 (complete)**: the live order queue (`OrderQueue` node + `_build_order_queue()` / `refresh_order_queue()` / `waiting_customers()`), the desktop price slider (`_price_slider` + `ACTION_PRICE_SET` → `Stand._set_price()`), and the richer day-end detail (`_format_day_end_detail()`: profit per location, rent per location, new unlocks). Also fixed the `.tscn` inline-style parse error and two bugs found by the new tests (queue rows piling up, the slider clobbering the price). Suite green at 127/127 + boot OK.
5. **Docs**: created `context.md` (this file), `todo.md` and `AGENTS.md` as mandatory living documents for every AI model, including a full folder/file index so a future agent can trace a bug without scanning every file.
6. **Task 9 (start)**: added `HUD/DayBar` ProgressBar to `UILayer.tscn`; restructured `DayEnd` into `DayEnd/Panel/Column` (Title/Summary/Detail/Continue); wired the day bar through `update_hud()` + `_on_time_tick()`; declared `_order_queue`, `_order_queue_label`, `_order_rows`, `_price_slider`, `_day_end_detail`, `ACTION_PRICE_SET`.
7. **Task 8 (complete)**: per-location rent (`Economy.charge_rent`), typed-array fixes in `Catalog`, shop panel + `TouchButtons/Shop` button, slot model across `StandEquipment`/`Inventory`/`PrepStation`, richer recap + `new_unlocks_for_day`. Suite green at 109/109.
8. Removed the double `money_changed` emit in `Inventory.buy_tool()`.
9. Deleted the temporary `tests/_probe.gd` debug probe.

---

## 14. Change Checklist (use before finishing any task)

1. [ ] Code compiles — `scripts\run_tests.cmd` runs the suite as a scene
2. [ ] Suite output shows the real pass/fail count; no "green" claims without running it
3. [ ] `todo.md` boxes ticked, session-log row added, known issues synced
4. [ ] `context.md` task table, test status, known issues and recent changes updated
5. [ ] No change to the 5 Implementer Decisions or the tuning table without saying so explicitly
