# Es Cekek — Implementation Plan

## Goal
A 3D simulation built in **Godot 4.x** (GDScript, single `.pck`). Run an "es di kantong plastik" (plastic-bag ice) stand in a neighborhood-scale open world: roam between locations (market, school gate, house front) via loading screens, pick a stand slot, receive shouted orders ("Bang mau es Tejus!"), pick the right sachet, prep the bag (pour → water → stir → ice → straw), price, and serve. **Quality** is driven by the **sachet's inherent price tier** (≈Rp 1k / 2k / 5k → richer flavor) and the **tools** the player owns; early player starts with only a table, sachet hook, water dispenser, and small ice cooler. Customers **never actually leave** during the wait — instead they get louder/annoyed and complain ("Lama amat", "Mau es apa berak bang?"). **MVP v1 ships Windows/Mac/Linux + Android APK.** Web/iOS/Console deferred. **No minigames** — quality is correctness + tier + tool-based, not timing-based.

## Scope (MVP v1)
- Open world = **medium neighborhood map with multiple small location scenes** loaded on demand (NOT one seamless map). Acceptable loading screen between locations for MVP.
- Locations (start): **Pasar** (market, busiest), **Sekolah** (school gate), **Rumang** (housing area, cheapest rent). Each has one Stand with seats + queue.
- 4 sachet (rendengan) brands live: Tejus, Marimas, Jasjus, Frenta.
- Day cycle 3 min/day. Single player. No network.

## Environment
- Working dir: `C:\Users\WIN10\Documents\Project\Es Cekek` — empty (no `project.godot`). Greenfield start.
- Godot 4.x editor + Android export templates must be installed. Directory is not currently a git repo.

## Tech Stack & Asset Policy
- Engine: Godot 4.x. Export: Windows (exe), Linux (x86_64), macOS (dmg), Android (APK).
- Visual: low-poly 3D (mobile-friendly). Language: GDScript. VC: init git repo.
- Input actions (InputMap): `move_forward/back/left/right`, `interact`, `ui_accept`, plus **prep actions**: `pour`, `add_water`, `stir`, `add_ice`, `add_straw`, `serve`, `travel`. Mapped to keyboard/gamepad on desktop and onscreen buttons on Android. `shake_*` from the earlier draft is **removed** (no minigame).
- Virtual joystick (move) + tap buttons, no overlap with UI sliders.

### Free Assets (CC0)
- People/characters: Kenney "Characters Top-Down" or Quaternius "Low Poly Characters" (walk/run/idle + crouch/seated).
- Props (ice bin, counter, sachet packs, plastic bags, straws): Kenney "Food Pack".
- Environment: Kenney "Nature Pack"/"Park"/"Buildings" for market/school/house.
- Audio: Kenney "Audio" (SFX: scoop/pour/stir; footsteps; complain "oof"/"ah" vocals; music loops).
- Import via `.import`; textures ≤512 for props, ≤1024 env, compressed (ETC2 Android, VRAM desktop).

## Architecture (scenes + nodes)

```
Main (Main.tscn / MainLoop.gd — persistent across loads)
 ├─ Player (Player.tscn: CharacterBody3D) — move + interact. StateMachine: ROAM / AT_STAND.
 ├─ LocationManager (singleton) — current_location, available_locations, LoadLocation(), fade/loading UI.
 ├─ Location (Location.tscn template: Node3D) — NavMesh, ground, static props, Stand slot(s).
 ├─ Stand (Stand.tscn) — counter, ice bin, `StandEquipment` node, cash register, seats + queue nodes, interaction hotspot.
 ├─ StandEquipment (node) — owned `Tool`s; exposes `ice_capacity`, `quality_mod`.
 ├─ PrepStation (PrepStation.tscn) — sachet rack (correct brand), pour/add_water/stir/add_ice/add_straw pipeline → emits a `Bag`.
 ├─ Bag (Bag.gd Resource) — sachet_portions, ice_amount, prep_quality (0–100, correctness), sell_price, cost.
 ├─ CustomerSystem (per-location spawner) — spawn customers, seat/queue them, run annoyance + complain lines, pay `Inventory`.
 ├─ Inventory (singleton) — sachet stock, ice stock, money, day earnings. (Consumed when a Bag is built, not when sold.)
 ├─ Economy (singleton) — day progression, rent per Location, end-of-day recap, unlocks.
 ├─ TimeOfDay (singleton) — 3-min day; drives sun/sky color + day/night lighting.
 └─ UILayer (singleton/Control) — money/day HUD, location picker, order callout + complain line, price setter, loading screen, day-end summary. Mobile layout.
```

### Data Resources
- `SachetBrand` (.tres): name, base_cost, **price_tier** (1000/2000/5000), **base_quality** (inherent flavor richness, e.g. 1k→0.35, 2k→0.60, 5k→0.85), sweetness, rarity (0–1), color_tint (Color), icon. (4 brands)
- `Tool` (.tres): id, name, cost, **quality_mod** (multiplier on prep), capacity_mod (e.g. ice cooler size), icon. Startup tools: `table`, `sachet_hook`, `water_dispenser`, `ice_cooler_small`.
- `LocationDef` (.tres): name, scene_path, rent_cost, foot_traffic (0–1, drives rate + `annoyance_rate`), seats (default 3), max_queue (default 5).
- `StandEquipment` (node on Stand): holds owned `Tool`s in slots; exposes `ice_capacity`, `quality_mod` to PrepStation. Player starts with the 4 startup tools; upgrades purchased via `UILayer`/Economy.
- `SachetPortion` (runtime): brand ref, volume (0–1). Stored on Bag.
- `Bag` (runtime): list<SachetPortion>, ice_amount (spoons), prep_quality (0–100, correctness×tier×tool), sell_price. Computes `cost` + price bounds.
- `Customer` (scene): order_brand (tier-weighted), `annoyance_level` (0–1), price_tolerance, state, `complain_lines`.

## Data Flow (one sale)
1. Customer spawns → finds a seat or joins queue → `UILayer` calls out the order ("Bang mau es [brand]!"). Annoyance starts ticking up.
2. While waiting: annoyance rises at `annoyance_rate` (faster at busy locations). At tiers 0.3/0.6/0.85/1.0 → complain line + crouch/seated visual. **Never leaves** until served.
3. Player at `PrepStation`: select **correct brand** from rack, `pour` (volume 0–1), `add_water`, `stir`, `add_ice` (0–8 spoons), `add_straw` → `Bag` built. **Ingredients consumed on build** (sachet + ice taken from Inventory regardless of sale outcome).
4. Player sets `Bag.sell_price` (≥ cost).
5. Player `interact`/approach the waiting customer → `serve`.
   - **Wrong brand**: customer protests ("Ini bukan [order]!"), pays nothing, bag trashed, `annoyance += 0.2`, stays in queue. (Realistic penalty: wasted ingredients + no revenue.)
   - **Right brand**: compute `satisfaction`, `tip`, `total_paid = sell_price + tip`. `Inventory.money += total_paid`; customer leaves happy, annoyance reset.
6. Repeat per customer until day ends.

## Game Systems & Formulas (implementer reference)

### prep_quality (0–100), tier × correctness × tool — NO minigame
Combined score reflects real stand quality:
- `base = SachetBrand.base_quality` (inherent flavor richness by price tier: 1k→0.35, 2k→0.60, 5k→0.85).
- `step_score` (0–1): weighted from stir, water, ice adequacy, volume, straw (same correctness checks; max 1.0).
- `tool_mod` = `StandEquipment.quality_mod` (startup tools ≈1.0; better cooler/mixer raise it).
- `prep_quality = round( base × step_score × tool_mod × 100 )`, clamped 0–100. Wrong brand → refuse gate (quality irrelevant).
- Visual: bag tint from `brand.color_tint` × `volume`; `prep_quality` low → dull/watery tint; a 5k sachet visibly darker/richer than a 1k.

### Bag cost & price bounds (Bag.gd)
- `cost = volume × brand.base_cost + ice_amount × ICE_COST_PER_SPOON`.
- `fair_price_min = cost × 1.10`.
- `fair_price_max = cost × 2.0`.
- Player may set any price ≥ `cost`; recommended hint = `cost × 1.35`. Lower-tier (1k) sachets need a lower price band to stay attractive; premium (5k) tolerates higher markup.

### Customer serve (Customer.gd)
- `order_brand` = weighted by `SachetBrand.rarity`.
- `price_tolerance` ∈ [0.7, 0.85] (random) × fair_max — keeps variety.
- `price_ratio = sell_price / fair_price_max`.
- `taste_fit` = 1.0 if brand right & 0.5 ≤ volume ≤ 1.0; else 0.6.
- `satisfaction = clamp( (prep_quality/100) × taste_fit × (1 − 0.6 × annoyance_level), 0, 1 )`.
- `tip = satisfaction × 0.4 × sell_price` if `price_ratio ≤ 1.5`; else **0** (customer shouts "Mahal amat!" but still **pays the price** — never fully refuses on price).
- `total_paid = sell_price + tip`.
- Wrong brand → refuse gate (no pay, trash bag, wasted ingredients) as above.

### Annoyance escalation (Customer.gd)
- `annoyance_level` ∈ [0,1], rises at `LocationDef.annoyance_rate` (busy location = faster). Reaches max ~45s idle by default.
- Tiers trigger complain audio lines:
  - 0.30 — "Lama amat, bang…"
  - 0.60 — "Mau es apa berak bang?" / "Ini esnya kok teh?"
  - 0.85 — "Wah, pelanggan lain mah cepat-cepat…"
  - 1.00 (max) — "Berhenti main HP, bang!" + crouch/seated. Still does not leave.
- Seated max per Stand = `LocationDef.seats`; overflow → `max_queue` standing. Beyond queue → spawns pause until a customer is served (documented guard).

### Bag tint (visual feedback)
- Final bag tint = weighted blend of served sachet `brand.color_tint` by `volume`; `prep_quality < 60` → desaturate tint (looks lukewarm).

### Failure modes (handled)
- Wrong brand: refuse path (no soft-lock; bag trashed, can rebuild).
- Player $0: restock disabled; can still vend existing stock; day ends with whatever profit/loss.
- Standing customers never leave: rely on `seats + max_queue` cap + spawn pause so stand doesn't infinitely clog. Documented; tunable.
- Location load failure → fall back to current Location with on-screen error; do not crash.

## World / Location Loading (mobile-friendly)
- Each Location is its own small `Location.tscn` (ground + NavMesh + a few buildings/props + Stand with seats + queue points).
- `LocationManager.LoadLocation(path)` frees previous Location nodes (keep Player/UI singletons), instances new scene, spawns Stand slots + CustomerSystem with the new `LocationDef`.
- Lightweight **fade + "sambungan" tip** between locations (loading screen is MVP-acceptable; seamless streaming is milestone 2).

## Mobile-Specific Concerns (Priority 1)
- Virtual joystick (move) left-bottom, prep buttons right-center, no overlap with UI sliders; ≥48dp touch targets.
- Perf: baked lighting (single directional), env tex ≤1024, prop tex ≤512, static batching, cull behind-camera props, one simple NavMesh per Location.
- UI: anchor-based `Control` + `size_override` so phone (~1080×2340) & tablet (~2560×1600) both fit; price setter uses +/- buttons on touch, slider on desktop.
- Export: `.pck` <100MB, compress textures, ETC2.

## Tasks (ordered)

- [ ] 1. Install Godot 4.x + Android templates. `git init`. Create `project.godot` (3D, Mobile renderer, GLES3), InputMap (`move_*`, `interact`, `pour`, `add_water`, `stir`, `add_ice`, `add_straw`, `serve`, `travel`, `ui_accept`), touch→mouse emulate, folder layout `assets/ src/ data/ locations/`.
- [ ] 2. Import CC0 assets. Build `Location.tscn` template: ground + baked directional light + simple NavMesh + one Stand slot placeholder.
- [ ] 3. Build `Player.tscn`: CharacterBody3D + ROAM/AT_STAND state machine, virtual joystick (Android) + WASD, tap-to-interact, camera follow.
- [ ] 4. Build `LocationManager` singleton + **Pasar** location scene: spawn Player + Stand + walkable ground, NavMesh movement, travel/loading UI.
- [ ] 5. Build `SachetBrand` resource + 4 brand `.tres` (assign price_tier 1000/2000/5000 + `base_quality`). Build `Tool` resource + startup `Tool` set (table, sachet_hook, water_dispenser, ice_cooler_small). Build `StandEquipment` node + `Inventory` singleton (money, sachet stock, ice stock, owned_tools). Implement consume-on-build rule.
- [ ] 6. Build `Stand.tscn` (counter, `StandEquipment` with 4 startup tools, ice cooler, cash register, seats + queue) + `PrepStation.tscn`: brand-matched rack, pour/add_water/stir/add_ice/add_straw pipeline using `StandEquipment.ice_capacity`/`quality_mod` → emits `Bag` with `prep_quality` = `base_quality × step_score × tool_mod`. Verify tier differences are visible + refuse/serve path.
- [ ] 7. Build `Customer` scene + spawner: NavMesh walk to Stand, `order` + `price_tolerance`, annoyance timer + tier complain lines (audio), seat/queue logic, serve evaluation (satisfaction/tip/refuse), pay `Inventory`.
- [ ] 8. Build `Economy` + `TimeOfDay` singletons: 3-min day, rent per Location, end-of-day recap (profit per location, best brand), next-day unlock.
- [ ] 9. Build `UILayer`: money + day/time HUD, order callout + complain line display, price +/- (touch) or slider (desktop), loading screen, day-end summary. Anchor + touch-target pass.
- [ ] 10. Add **Sekolah** + **Rumah** locations (`LocationDef` with distinct rent/foot_traffic/annoyance_rate); wire LoadLocation travel; confirm Player/Inventory/Economy/TimeOfDay persist.
- [ ] 11. **Android QA**: export APK, install, verify move joystick + prep taps + serve + UI on ~1080×2340 and ~2560×1600. Per + day-night lighting. APK size check. Windows exe sanity test.
- [ ] 12. Polish: confirm SFX + complain vocal lines + music loop, basic VFX (pour/stir/ice clink), location-distinct colors. Ship `EsCekek_MVP_v1`.

## Validation Plan
- **Functional**: travel all 3 locations without crash; one seat at each; 5 full days no soft-lock; buy all 4 brands.
- **Simulation depth**: wrong brand → refuse + waste + no pay; overprice (>1.5×) → "Mahal amat" + zero tip but still pays; higher prep_quality → higher tip; busier location → faster annoyance.
- **Stand realism**: waiting customers complain at tiers & crouch-seat; never leave voluntarily; queue cap pauses spawns.
- **Mobile QA**: joystick move; prep taps register; no UI clipping phone/tablet; 30fps sustained; complain text visible.
- **Export QA**: APK installs & runs Android 10+; Windows exe exits cleanly; build reproducible from `project.godot`.
- **Exit criteria**: roaming + 3 locations + prep/serve loop + annoyance escalation + APK export working.

## Constraints & Risks
- Mobile perf is binding — reduce props/bake lighting rather than cut gameplay.
- Scope lock MVP: no seamless streaming, no premium brands, no Web/iOS/console, no minigames, no network.
- Asset budget: 4 brands + 3 locations + 1 character set. CC0 shortfall → flat-shaded color materials, not new free searches.
- Day length: 3 min tunable via `TimeOfDay.DAY_SECONDS`.

## Out of Scope (deferred)
- Web/HTML5, iOS, console.
- Seamless open world; premium brands (Good Day/Pop Ice/Nutrisari) and extra locations; multiplayer/network; custom art beyond CC0; in-app purchases.

## Implementer Decisions (must pick — not left to interpretation)
- **Consumption timing**: sachet + ice consumed when the `Bag` is **built**, not when sold. Wrong-brand refusal still consumes (wasted) the ingredients — realistic penalty, no soft-lock since a rebuild is always possible if stock remains.
- **Overpricing**: customer never fully refuses on price; above 1.5× fair_max → "Mahal amat" + zero tip but still pays `sell_price`. Refuse **only** happens on wrong brand.
- **Queue cap**: `seats`=3 + `max_queue`=5 per Stand; beyond that, spawns pause until a customer is served (prevents infinite stand clogging without ever "leaving"). Tunable in `LocationDef`.
- **Annoyance never expels**: documented as a deliberate realism choice, not a bug. If it stalls a playtest, the lever is `annoyance_rate` per Location, not adding a "leave" path.
- **Day length**: lever is `TimeOfDay.DAY_SECONDS`; do not shorten by reducing customer patience.

## Tuning Parameter Reference
| Parameter | Location | Default |
|---|---|---|
| `TimeOfDay.DAY_SECONDS` | TimeOfDay.gd | 180 |
| `ICE_COST_PER_SPOON` | Bag.gd | 0.2 |
| `MAX_SPOON_ICE` | PrepStation.gd | 8 |
| `FAIR_PROFIT_FLOOR/MAX` (× cost) | Bag.gd | 1.10 / 2.0 |
| `TIP_MULTIPLIER` | Customer.gd | 0.4 |
| `PRICE_COMPLAIN_AT` (× cost) | Customer.gd | 1.5 |
| `ANNOYANCE_MAX_WAIT` (s) | Customer.gd | ~45 (scales by location) |
| `ANNOYANCE_TIERS` | Customer.gd | 0.30 / 0.60 / 0.85 / 1.00 |
| `SEATS_PER_STAND` | LocationDef | 3 |
| `MAX_QUEUE_PER_STAND` | LocationDef | 5 |
| `LOCATION_RENT_PER_DAY` | LocationDef | Pasar 30 / Sekolah 20 / Rumah 15 |
| `CUSTOMER_PRICE_TOLERANCE` | Customer.gd | 0.7–0.85 × fair_max |
| `SACHETF_BASE_QUALITY` | SachetBrand (1k/2k/5k) | 0.35 / 0.60 / 0.85 |
| `STARTUP_TOOLS` | StandEquipment | table, sachet_hook, water_dispenser, ice_cooler_small |
| `ICE_CAPACITY_SMALL` (spoons) | Tool/ice_cooler_small | 8 |
| `TOOL_QUALITY_MOD_BASE` (startup) | StandEquipment | 1.0 (improves with upgrades) |

## Next Step for Implementer
Read this plan, install Godot 4.x + Android export templates, `git init`, and begin **Task 1** (project scaffolding + InputMap + folder layout). Confirm the five **Implementer Decisions** during Task 6/7 review; no other design ambiguity should block the build.
