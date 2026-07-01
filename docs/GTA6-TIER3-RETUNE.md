# GTA6-TIER3-RETUNE — the map/model fill-in-the-blanks worksheet

Tier 3 (see `docs/GTA6-READINESS.md` §2) is everything bound to the **Los
Santos map, the GTA V model set, or GTA V native ids**. GTA VI ships a new
map (Leonida / Vice City), new model names, and new native ids, so these
values do **not** port — they get re-authored against the new world.

The good news, and the whole point of the bridge work: the **structure**
holding these values is Tier 1 and already portable. So this is not a
rewrite — it is filling in a column. When GTA VI tooling exists:

1. Fill the **GTA VI value** column below (or edit the companion
   `gta6-tier3-retune.csv` in a spreadsheet).
2. Paste each value back into its **Source file**.
3. Keep the two spawn entries (§1) identical — they are cross-referenced.

Every "Current (GTA V)" value here was extracted from the live config on
2026-06-30. If a config changes, update this worksheet (it is a living doc,
like the readiness map).

> Item **catalog** data (labels, prices, weights) and job **design** (grades,
> salaries, payout bounds, densities-as-ratios) are **Tier 1** — they carry.
> Only the map coords, the GTA-model names, and the native-id levers below are
> Tier 3.

---

## 1. Spawn point

Keep both entries identical — `server_base` reads its copy as the canonical
value and `server_identity` repositions the character to it.

| Item | Current (GTA V) | GTA VI value | Source file |
| --- | --- | --- | --- |
| Default spawn — Legion Square | `vector4(195.17, -933.77, 30.69, 144.0)` | _TBD_ | `resources/[custom]/server_identity/config.lua` → `Config.SpawnPoint` |
| Default spawn (mirror) | `vector4(195.17, -933.77, 30.69, 144.0)` | _TBD_ | `resources/[custom]/server_base/config.lua` → `Config.DefaultSpawn` |

## 2. Emergency-services coords

Source: `resources/[custom]/[config_overrides]/qbx_police_overrides/config.lua`
and `.../qbx_ambulance_overrides/config.lua`.

| Item | Current (GTA V) | GTA VI value | Key |
| --- | --- | --- | --- |
| Police armoury — Mission Row | `vector3(461.79, -983.04, 30.69)` r1.2 | _TBD_ | police `Config.Armoury[1].coords` |
| Police duty toggle — Mission Row | `vector3(442.32, -988.43, 30.69)` r1.0 | _TBD_ | police `Config.DutyToggle.coords` |
| Ambulance hospital — Pillbox Hill | `vector3(307.7, -1433.4, 29.9)` r3.0 | _TBD_ | ambulance `Config.Hospitals[1].coords` |
| Ambulance duty toggle — Pillbox Hill | `vector3(311.5, -1432.0, 30.0)` r1.0 | _TBD_ | ambulance `Config.DutyToggle.coords` |

## 3. Civilian job starter NPCs

Source: `.../qbx_civilian_jobs_overrides/config.lua` → `Config.Jobs.<job>.starter_npc.coords`.

| Item | Current (GTA V) | GTA VI value | Key |
| --- | --- | --- | --- |
| Trucker Dispatch | `vector3(150.95, -3040.0, 7.04)` r1.5 | _TBD_ | `trucker` |
| Downtown Cab Co. (taxi) | `vector3(903.13, -174.83, 73.97)` r1.5 | _TBD_ | `taxi` |
| LS Sanitation (garbage) | `vector3(-322.65, -1545.13, 27.79)` r1.5 | _TBD_ | `garbage` |
| Benny's — LS Customs (mechanic) | `vector3(-205.45, -1311.66, 31.30)` r1.5 | _TBD_ | `mechanic` |

## 4. Shop world coords

Source: `.../ox_inventory_overrides/data/shops.lua` → `ExtraShops.<shop>.locations`.
Labels/prices/inventory are Tier 1 (carry); only the coords are Tier 3.

| Shop | # | Current (GTA V) | GTA VI value |
| --- | --- | --- | --- |
| General Store | 1 | `vector3(24.47, -1346.62, 29.50)` — Innocence Blvd | _TBD_ |
| General Store | 2 | `vector3(-3038.94, 585.95, 7.91)` — Pacific Bluffs | _TBD_ |
| General Store | 3 | `vector3(-3242.47, 1001.46, 12.83)` — Banham Canyon | _TBD_ |
| General Store | 4 | `vector3(1728.66, 6414.16, 35.04)` — Paleto Bay | _TBD_ |
| General Store | 5 | `vector3(1163.37, -323.80, 69.21)` — Mirror Park | _TBD_ |
| General Store | 6 | `vector3(2557.94, 382.05, 108.62)` — Tataviam Mtns | _TBD_ |
| General Store | 7 | `vector3(373.87, 325.89, 103.57)` — Downtown | _TBD_ |
| Ammu-Nation | 1 | `vector3(21.7, -1106.42, 29.80)` — Innocence Blvd | _TBD_ |
| Ammu-Nation | 2 | `vector3(810.25, -2157.6, 29.62)` — El Burro Heights | _TBD_ |
| Ammu-Nation | 3 | `vector3(1693.4, 3760.6, 34.71)` — Sandy Shores | _TBD_ |
| Hardware Store | 1 | `vector3(2748.4, 3473.4, 55.66)` — Sandy Shores | _TBD_ |
| Hardware Store | 2 | `vector3(-422.7, 6136.0, 31.86)` — Paleto Bay | _TBD_ |
| Suburban (clothing) | 1 | `vector3(127.0, -223.4, 54.56)` | _TBD_ |
| Police Armoury (society) | 1 | `vector3(461.79, -983.04, 30.69)` | _TBD_ |
| EMS Medical Supply (society) | 1 | `vector3(307.7, -1433.4, 29.9)` | _TBD_ |

## 5. Vehicle model names

Source: police/ambulance overrides `Config.VehicleAllowed`. GTA VI ships a new
vehicle model set — re-map each to its VI equivalent.

| Fleet | Current (GTA V models) | GTA VI models | Source |
| --- | --- | --- | --- |
| Police motor pool | `police, police2, police3, policeb, policet` | _TBD_ | `qbx_police_overrides/config.lua` |
| Ambulance motor pool | `ambulance` | _TBD_ | `qbx_ambulance_overrides/config.lua` |

## 6. Weapon model names (loadouts)

Source: police/ambulance overrides `Config.LoadoutAllowed`. The **item names**
are catalog data (Tier 1) *if* the same item exists in the new inventory, but
each `weapon_*` name maps to a GTA V weapon model/hash — re-map those. Non-
weapon items (ammo, handcuffs, radio, armor, bandage, medikit, etc.) are Tier 1
and carry.

| Job | GTA-model-bound entries (GTA V) | GTA VI equivalents | Source |
| --- | --- | --- | --- |
| Police | `weapon_combatpistol, weapon_stungun, weapon_nightstick, weapon_flashlight` | _TBD_ | `qbx_police_overrides/config.lua` |
| Ambulance | (no weapon models — all Tier 1 items) | n/a | `qbx_ambulance_overrides/config.lua` |

## 7. Blip sprites & colours

Source: `resources/[custom]/gtarp_courier/bridge/cl_game.lua` →
`Game.CreateRouteBlip`. Blip sprite/colour ids are GTA V native ids; re-map to
the GTA VI blip id table. (This is the only custom-authored blip — recipe jobs
own their own blips upstream.)

| Item | Current (GTA V) | GTA VI value |
| --- | --- | --- |
| Courier delivery blip — sprite | `1` | _TBD_ |
| Courier delivery blip — colour | `5` (default) | _TBD_ |

## 8. Population density levers

Source: `.../qbx_density_overrides/config.lua` → `Config.Density`. The
**values** (0.0–1.0 ratios) are design and likely carry, but they feed GTA V
population natives (`SetPedDensityMultiplierThisFrame`, etc.) — confirm the
GTA VI native names/behaviour and re-map the density-type keys if they change.

| Lever | Current value | GTA VI value | Note |
| --- | --- | --- | --- |
| `peds` | `0.9` | _carry?_ | walking civilians |
| `vehicle` | `0.7` | _carry?_ | moving traffic (heaviest perf cost) |
| `randomvehicles` | `0.7` | _carry?_ | rarer ambient vehicles |
| `parked` | `0.8` | _carry?_ | parked cars |
| `scenario` | `0.7` | _carry?_ | scripted scenario crowds |

## 9. Housing — doors & shell interiors

Source: `resources/[custom]/gtarp_housing/shared/config.lua`
(`Config.Properties[*].door` and `Config.Shells[*].interior`). The buy/sell/
keys/instancing lifecycle is Tier 1; only these coords are Tier 3.

| Item | Current (GTA V) | GTA VI value | Key |
| --- | --- | --- | --- |
| Property door — Integrity Way | `vector4(-47.24, -585.35, 36.96, 340.0)` | _TBD_ | `Properties integrity_1` |
| Property door — Del Perro Heights | `vector4(-1447.06, -538.79, 34.74, 145.0)` | _TBD_ | `Properties delperro_1` |
| Property door — Mirror Park Blvd | `vector4(1148.90, -1521.30, 34.90, 100.0)` | _TBD_ | `Properties mirror_1` |
| Property door — Alhambra Dr (Sandy) | `vector4(1972.40, 3815.20, 33.43, 120.0)` | _TBD_ | `Properties sandy_1` |
| Shell interior — apartment | `vector4(266.09, -1007.98, -101.01, 0.0)` | _TBD_ | `Shells apartment` |
| Shell interior — mid house | `vector4(346.20, -1013.10, -99.20, 0.0)` | _TBD_ | `Shells mid` |
| Shell interior — trailer | `vector4(1973.30, 3818.40, 33.43, 60.0)` | _TBD_ | `Shells trailer` |

---

## Not in this worksheet (intentionally)

- **Recipe-owned map values** (qbx_core default spawn fallback, recipe job
  blips, recipe garage/impound coords) — those live in Tier 0 resources we
  don't own; the community's GTA VI framework will re-author them.
- **Our own SQL, item catalog, economy math, allowlist, rules, staff matrix**
  — Tier 1, carries unchanged.
