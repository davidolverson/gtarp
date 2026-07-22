# Business interiors — shell capture guide

Companion to the `Config.Interiors` gate in the go-live runbook. This is the
in-game session: capturing the interior "shells" that make storefronts enterable.
Read it before you hop in so the session is fast.

## The one-paragraph model

A **shell** is an existing, already-in-the-map interior that you point businesses
at. You don't build it — you stand in one and `/bizshell` records its position.
Every business of a type teleports into that one shell, each in its own private
routing bucket (so instances never see each other), and each business dresses the
room with its own props. You capture a shell **once**; all businesses of that type
reuse it forever.

## Prerequisites

1. `Config.Interiors = true` in `palm6_business/shared/config.lua`, deployed +
   started. `/bizshell` is inert until then.
2. You have the `command.bizshell` ace (admin). Console can't capture (no position).
3. `Config.Phase1Enabled` is already on (storefronts) — interiors build on them.

## The capture loop

For each interior you want to use:

1. Walk **inside** the real interior (through the door — be standing where you want
   players to appear).
2. Run `/bizshell <type> [label]` — e.g. standing in a bar, `/bizshell bar Yellow Jack`.
   - `<type>` accepts a **business type** (`restaurant` `bar` `garage` `retail`
     `dealership`) and auto-maps to that type's shell key. Or pass a raw shell key.
   - `[label]` is a friendly name (optional; defaults to the key).
   - If it warns "no interior detected," that's a **soft** warning — capture still
     happens. It fires for map-mesh walk-ins (many 24/7s) that are valid anyway.
     Only worry if, after going live, players land in the street: then re-capture.
3. `/bizshells` — lists everything captured and, crucially, **which type mappings
   still have no shell** (the "Enter never appears" trap). Repeat until it's empty
   or you're happy.
4. Walk up to a placed storefront of that type → an **Enter** option appears → walk
   in → confirm you land inside the room, not the floor/void. Re-capture if off.

Re-capturing is safe and idempotent (`ON DUPLICATE KEY UPDATE`) — stand in a better
spot, run it again, done.

## What base-game interiors to use (no downloads)

Base-game enterable interiors are plentiful for **retail** and **bar**, thin for the
others. Honest per-type guidance:

| Type | Base-game fit | Where to stand |
|---|---|---|
| **retail** | ✅ Great | Any 24/7, Rob's Liquor, LTD, an Ammu-Nation, or a clothing store (Binco/Suburban/Ponsonbys/Discount). Pick a roomy one. |
| **bar** | ✅ Good | Yellow Jack (Sandy Shores), or the Vanilla Unicorn main floor. Real bar rooms. |
| **restaurant** | 🔶 No true base interior | Cluckin' Bell / Burger Shot are exterior shells only. Reuse a 24/7 or bar shell for now; an MLO is the real upgrade (see the interiors memory / research note). |
| **garage** | 🔶 No clean base interior | No public enterable garage in base game. Reuse a retail/warehouse-ish interior for now; MLO later. |
| **dealership** | 🔶 No base showroom | No enterable car showroom in base game. Reuse a retail shell for now; MLO later. |

### Fastest path to "everything is enterable"

Capture **one** roomy retail interior, then point every type at it in
`Config.Interior.TypeShell`:

```lua
TypeShell = {
    restaurant = 'shell_retail',
    bar        = 'shell_retail',
    garage     = 'shell_retail',
    retail     = 'shell_retail',
    dealership = 'shell_retail',
},
```

Now every business of every type is walk-in-able off a single captured shell. The
per-business **prop layout** still makes them look different. Refine to
type-specific shells (and eventually MLOs) later without touching any business data.

## After capture — tuning the look

- Owner opens `/business` → Storefront → **Interior style** to pick a layout
  (bare / stocked / lounge / workshop / upscale). This is what differentiates two
  shops sharing a shell.
- The layout prop names in `Config.Interior.Layouts` are **starter values, not yet
  verified in this build**. When you walk into a layout, any prop whose model name
  is wrong prints to the console:
  `[palm6_business] layout "workshop": N prop(s) failed to load ...: <names>`.
  Swap those names for ones that render (a prop viewer helps) and redeploy. Missing
  props are skipped, never fatal — a bad name just means a sparser room.

## Rollback

Set `Config.Interiors = false` + redeploy. Captured shells persist in
`palm6_business_shells` and simply go unused; storefronts revert to Phase-1a
(blip + walk-up) with no Enter option. No data migration, fully reversible.
