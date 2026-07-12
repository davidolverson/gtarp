#!/usr/bin/env bash
# ============================================================================
# tools/patch-vehicle-prices.sh <path-to-deployed-resources-dir>
#
# Rewrites the `price =` field in the LIVE qbx_core/shared/vehicles.lua for each
# model in gtarp_dealership/shared/catalog.lua to its Palm6 tier price. Touches
# NOTHING else — no coords, categories, hashes, types, or non-listed models. The
# catalog resource is the single source of truth; this is the deploy-time half
# that qbx_core actually reads (qbx_vehicleshop pulls prices from qbx_core's
# vehicle data, and there is no runtime "set price" export, so a file patch is
# the honest mechanism — same story as patch-ox-items.sh).
#
#   bash tools/patch-vehicle-prices.sh "/c/.../txData/QboxLeanPack_0DF2F5.base/resources"
#
# Run after every deploy, BEFORE boot. Idempotent (re-running sets the same
# prices). Prints a per-model old->new diff and lists any catalog model not found
# in this qbx_core version (a warning, not a failure). Leaves the live file
# untouched on any parse error.
# ============================================================================
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="$REPO/resources/[custom]/gtarp_dealership/shared/catalog.lua"
RES_DIR="${1:?usage: patch-vehicle-prices.sh <deployed-resources-dir>}"

[ -f "$CATALOG" ] || { echo "ERROR: missing $CATALOG" >&2; exit 1; }
[ -d "$RES_DIR" ] || { echo "ERROR: not a directory: $RES_DIR" >&2; exit 1; }

# qbx_core's location varies by recipe layout ([qbx]/qbx_core is the Qbox lean
# default). Find it rather than hardcode a single guessed path.
TARGET=""
for cand in \
    "$RES_DIR/[qbx]/qbx_core/shared/vehicles.lua" \
    "$RES_DIR/[qb]/qbx_core/shared/vehicles.lua" \
    "$RES_DIR/[core]/qbx_core/shared/vehicles.lua" \
    "$RES_DIR/qbx_core/shared/vehicles.lua"; do
    [ -f "$cand" ] && { TARGET="$cand"; break; }
done
if [ -z "$TARGET" ]; then
    TARGET="$(find "$RES_DIR" -type f -path '*qbx_core/shared/vehicles.lua' 2>/dev/null | head -1 || true)"
fi
[ -n "$TARGET" ] && [ -f "$TARGET" ] || {
    echo "ERROR: could not locate qbx_core/shared/vehicles.lua under $RES_DIR" >&2; exit 1; }

# native python on Windows can't open /c/... paths — hand it native ones
if command -v cygpath >/dev/null 2>&1; then
    CATALOG="$(cygpath -w "$CATALOG")"; TARGET="$(cygpath -w "$TARGET")"
fi

python - "$CATALOG" "$TARGET" <<'PY'
import re, sys

catalog_path, target_path = sys.argv[1], sys.argv[2]
cat = open(catalog_path, encoding="utf-8").read()

# --- parse TierPrices: `<tier> = <int>,` inside the TierPrices block ---------
mt = re.search(r"TierPrices\s*=\s*\{(.*?)\n\}", cat, re.S)
if not mt:
    sys.exit("ERROR: could not find Catalog.TierPrices in catalog.lua")
tiers = {t: int(p) for t, p in re.findall(r"(\w+)\s*=\s*(\d+)\s*,", mt.group(1))}
if not tiers:
    sys.exit("ERROR: TierPrices parsed empty")

# --- parse Vehicles: strict { model = '..', tier = '..', ... } lines,
# scoped to the Catalog.Vehicles block so header comment examples never match --
mv = re.search(r"Vehicles\s*=\s*\{(.*?)\n\}", cat, re.S)
if not mv:
    sys.exit("ERROR: could not find Catalog.Vehicles in catalog.lua")
vehicles = re.findall(r"model\s*=\s*'([^']+)'\s*,\s*tier\s*=\s*'([^']+)'", mv.group(1))
if not vehicles:
    sys.exit("ERROR: no vehicles parsed from catalog.lua (check the strict line format)")

want = {}
for model, tier in vehicles:
    if tier not in tiers:
        sys.exit(f"ERROR: model {model} references unknown tier {tier}")
    want[model] = tiers[tier]

text = open(target_path, encoding="utf-8").read()

changed, unchanged, missing = [], [], []
for model, newprice in want.items():
    # Match the whole entry block, key either bare (adder = {) or quoted
    # (['adder'] = {), up to the closing brace at the key's indent.
    key = re.escape(model)
    block_re = re.compile(
        r"(?ms)^(?P<i>[ \t]*)(?:\['" + key + r"'\]|" + key + r")\s*=\s*\{"
        r"(?P<body>.*?)^\1\}",
    )
    m = block_re.search(text)
    if not m:
        missing.append(model)
        continue
    body = m.group("body")
    pm = re.search(r"(price\s*=\s*)(\d+)", body)
    if not pm:
        missing.append(model + "(no price field)")
        continue
    oldprice = int(pm.group(2))
    if oldprice == newprice:
        unchanged.append(model)
        continue
    new_body = body[:pm.start()] + pm.group(1) + str(newprice) + body[pm.end():]
    text = text[:m.start("body")] + new_body + text[m.end("body"):]
    changed.append((model, oldprice, newprice))

open(target_path, "w", encoding="utf-8", newline="\n").write(text)

print(f"patched {target_path}")
print(f"  changed:   {len(changed)}   unchanged(already-set): {len(unchanged)}   missing: {len(missing)}")
for model, old, new in sorted(changed):
    print(f"    {model:14s} {old:>8} -> {new}")
if missing:
    print("  WARNING — catalog models not found in this qbx_core (skipped, no change):")
    print("    " + ", ".join(sorted(missing)))
PY
