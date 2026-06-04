# ox_inventory shops export — current state and required changes

Read-only reference check against upstream `overextended/ox_inventory`. No
upstream files were modified; no files outside this note were touched.

## Reference checked

- Repo: `overextended/ox_inventory`
- Tag:  `v2.47.5` (latest release at time of writing)
- Commit: `c20ea6bdbb4d508c62f2439e7c4bd4b50bc0600b`
- Files inspected (raw, verbatim, on that tag):
  - `fxmanifest.lua`
  - `modules/shops/server.lua`
  - `modules/shops/client.lua`
  - `modules/items/server.lua`
  - `data/shops.lua`

## TL;DR

- The current upstream **does not** expose a `Shops()` getter — there is no
  `exports.ox_inventory:Shops()`. Our `ox_inventory_overrides/server/apply.lua`
  calls that export and the call is silently swallowed by its `pcall`. **Our
  custom shops are not being registered today.**
- The current canonical way to add a shop at runtime is the server-side export
  **`exports.ox_inventory:RegisterShop(shopType, shopDetails)`**, defined in
  `modules/shops/server.lua` at the line `exports('RegisterShop', …)`.
- For **items**, `exports.ox_inventory:Items()` still exists (defined in
  `modules/items/server.lua` as `exports('Items', …)`), and returns the live
  `ItemList` table. Mutating that table — what our `applyItems()` already does
  — remains the working server-side registration path. No change needed there.
- **Important caveat** for shops: `RegisterShop` only registers the shop on
  the **server** side. The client-side blip / ox_target / ped rendering for a
  shop is built once at client load from `lib.load('data.shops')` in
  `modules/shops/client.lua`. There is no client-side `RegisterShop` export
  and no server→client sync of newly registered shops. A `RegisterShop` call
  alone gives a shop that the buy/sell server callbacks accept, but it has no
  visible interaction surface unless the player is steered into it some other
  way (e.g. by code in another resource that opens it explicitly).

## Current export surface (v2.47.5)

### Shops module (`modules/shops/server.lua`)

```lua
---@param shopType string
---@param shopDetails OxShop
exports('RegisterShop', function(shopType, shopDetails)
    registerShopType(shopType, shopDetails)
end)
```

- Server-side only.
- `shopType` is the string key (e.g. `'CoffeeShop'`, `'PoliceArmoury'`).
  This is the same key shape used by entries in `data/shops.lua`.
- `shopDetails` is the same table shape as a `data/shops.lua` entry. Fields
  observed in the v2.47.5 stock file:
  - `name`        : display label
  - `blip`        : `{ id, colour, scale }`
  - `groups`      : optional, e.g. `shared.police` or `{ ['ambulance'] = 0 }`
                    — gates access by job + grade
  - `inventory`   : array of slots, each `{ name, price, count?, metadata?,
                    license?, currency?, grade? }`
  - `locations`   : array of `vec3` (used when targeting is off)
  - `targets`     : array of target entries `{ loc, length, width, heading,
                    minZ, maxZ, distance }` (used when `shared.target` is on)
  - `model`       : optional model hashes for vending-machine-style shops
- The internal `Shops` table is module-local; `server.shops = Shops` exposes
  it on the internal `server` table only, **not** as an export. There is no
  way to read or mutate it from another resource except via `RegisterShop`.
- `registerShopType` accepts both the location-based and the
  pre-prepared/no-location forms; see the function body.

### Shops module (`modules/shops/client.lua`)

```lua
for shopType, shopData in pairs(lib.load('data.shops') or {} …) do
    -- builds local `shopTypes[shopType]` and blip text entries
end
```

- Client builds its `shopTypes` table once at module load.
- The module returns `{ refreshShops, wipeShops }`. Both operate only on the
  client-local `shopTypes` populated above; neither pulls in new shops.
- **No client-side `RegisterShop` export exists.**

### Items module (`modules/items/server.lua`)

```lua
exports('Items', function(item) return getItem(nil, item) end)
exports('ItemList', function(item) return getItem(nil, item) end)
```

- `Items()` (no arg) returns the live `ItemList` table (via `__call`
  metamethod / `getItem(nil, nil)`).
- `Items(name)` returns one item.
- Mutating the returned table to add an item (what our `applyItems()` does)
  remains valid.

## What our `ox_inventory_overrides` does today

File: `resources/[custom]/[config_overrides]/ox_inventory_overrides/server/apply.lua`

- `applyItems()` calls `exports.ox_inventory:Items()` and merges
  `ExtraItems` into the returned table. **This works.**
- `applyShops()` calls `exports.ox_inventory:Shops()` and tries to merge
  `ExtraShops` into the returned table. **This silently fails** — there is no
  `Shops` export. The `pcall` catches the missing-method error, prints
  `[ox_inventory_overrides] ox_inventory:Shops() unavailable; skipping merge`,
  and returns 0. None of our custom shops get registered.

## What needs to change

Two changes in `apply.lua`, both confined to `applyShops()`. No upstream
changes; no other custom-layer files affected.

1. Drop the call to the non-existent `exports.ox_inventory:Shops()`.
2. Iterate `ExtraShops` and call `exports.ox_inventory:RegisterShop(key, shop)`
   once per entry. Recommended sketch (not committed in this PR):

   ```lua
   local function applyShops()
       local exp = exports.ox_inventory
       if type(exp) ~= 'table' and type(exp) ~= 'userdata' then
           print('[ox_inventory_overrides] ox_inventory exports unavailable; skipping')
           return 0
       end

       local added = 0
       for key, shop in pairs(ExtraShops) do
           local ok, err = pcall(function()
               exp:RegisterShop(key, shop)
           end)
           if ok then
               added = added + 1
           else
               print(('[ox_inventory_overrides] RegisterShop(%s) failed: %s'):format(key, tostring(err)))
           end
       end
       return added
   end
   ```

   The existing `validateShops()` and `onResourceStart` wiring keep working
   unchanged — the shape of `ExtraShops` entries already matches what
   `RegisterShop` expects (same as `data/shops.lua` entries).

### Caveat the change does NOT fix

`RegisterShop` registers a shop **server-side** only. The client side of
ox_inventory builds its shop renderer once at load from `data/shops.lua` and
never re-reads it. So after the fix:

- Server callbacks (`ox_inventory:openShop`, `ox_inventory:buyItem`) will
  accept our `ExtraShops` keys, prices, group gates, and licenses.
- Clients will **not** automatically gain blips, ox_target zones, or shop
  peds for our custom shops, because the client renderer never sees them.

Options if we want visible shops without forking ox_inventory:

- **(a) Server-side only "headless" shops** — fine for any shop opened
  programmatically by another resource (e.g. via
  `exports.ox_inventory:openInventory(source, 'shop', { type = key, id = 1 })`
  triggered by our own ox_target hook or NPC interaction script). This is
  the lowest-touch path: keep our shops table here, register them, and add
  one of our own NPCs/targets that opens the shop.
- **(b) Build our own client-side blip+target spawner** that reads the same
  `ExtraShops` table (shared between client and server) and uses ox_target +
  blip APIs to mirror what `modules/shops/client.lua` does for built-ins.
- **(c) Fork ox_inventory** and either edit `data/shops.lua` or add a
  client-side `RegisterShop` export and a server→client broadcast. Highest
  ongoing maintenance cost.

Option (a) is the simplest correct path for shops that are accessed via
custom NPCs/targets we already control; (b) is the right answer if we want
parity with ox_inventory's built-in shop UX without forking.

## Out of scope for this note

Per the issue brief: no live-server work, no SQL, no custom-layer file
edits, no upstream edits. This file is research only; the actual fix to
`server/apply.lua` (and the option (a)/(b) decision) belongs in a separate
PR.
