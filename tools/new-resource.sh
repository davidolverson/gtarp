#!/usr/bin/env bash
# ============================================================================
# tools/new-resource.sh <name> [--db] [--client-only] [--server-only]
#
# Scaffolds a new bridge-pattern-native custom resource under
# resources/[custom]/gtarp_<name>/ so it is GTA-VI-portable from day one
# (see docs/GTA6-READINESS.md). Logic goes in server/ + client/; every
# framework/native call lives in bridge/. Also reminds you to wire the
# `ensure` line into custom.cfg.
#
#   bash tools/new-resource.sh fishing            # client+server, no DB
#   bash tools/new-resource.sh robbery --db       # + oxmysql dep + sql stub
#   bash tools/new-resource.sh hud --client-only
# ============================================================================
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CU="$REPO/resources/[custom]"

NAME=""; WITH_DB=0; CLIENT=1; SERVER=1
for a in "$@"; do
  case "$a" in
    --db) WITH_DB=1 ;;
    --client-only) SERVER=0 ;;
    --server-only) CLIENT=0 ;;
    --*) echo "unknown flag: $a" >&2; exit 1 ;;
    *) NAME="$a" ;;
  esac
done
[ -n "$NAME" ] || { echo "usage: new-resource.sh <name> [--db] [--client-only] [--server-only]" >&2; exit 1; }
echo "$NAME" | grep -qE '^[a-z][a-z0-9_]*$' || { echo "name must be lower_snake_case (got '$NAME')" >&2; exit 1; }

RES="gtarp_$NAME"
DIR="$CU/$RES"
[ -e "$DIR" ] && { echo "ERROR: $DIR already exists" >&2; exit 1; }
mkdir -p "$DIR/shared"
[ "$CLIENT" = 1 ] && mkdir -p "$DIR/client" "$DIR/bridge"
[ "$SERVER" = 1 ] && mkdir -p "$DIR/server" "$DIR/bridge"

# ---- fxmanifest.lua -------------------------------------------------------
{
  echo "fx_version 'cerulean'"
  echo "game 'gta5'"
  echo "lua54 'yes'"
  echo
  echo "author 'EvThatGuy'"
  echo "version '0.1.0'"
  echo "description 'gtarp $NAME'"
  echo
  if [ "$CLIENT" = 1 ]; then
    echo "shared_scripts {"
    echo "    '@ox_lib/init.lua',"
    echo "    'shared/config.lua',"
    echo "}"
    echo
    echo "client_scripts {"
    echo "    'bridge/cl_game.lua',   -- game adapter — must load before client logic"
    echo "    'client/main.lua',"
    echo "}"
  fi
  if [ "$SERVER" = 1 ]; then
    echo
    echo "server_scripts {"
    [ "$WITH_DB" = 1 ] && echo "    '@oxmysql/lib/MySQL.lua',"
    # --server-only: no shared_scripts block (nothing to ship to clients) —
    # config.lua loads here instead. Precedent: gtarp_bounty's hand-fixed manifest.
    [ "$CLIENT" = 0 ] && echo "    'shared/config.lua',"
    echo "    'bridge/sv_framework.lua',  -- framework adapter — before server logic"
    echo "    'server/main.lua',"
    echo "}"
  fi
  echo
  echo "dependencies {"
  echo "    'ox_lib',"
  [ "$WITH_DB" = 1 ] && echo "    'oxmysql',"
  echo "    'qbx_core',"
  echo "}"
} > "$DIR/fxmanifest.lua"

# ---- shared/config.lua ----------------------------------------------------
cat > "$DIR/shared/config.lua" <<EOF
-- ============================================================================
-- $RES/shared/config.lua — engine-agnostic tunables (Tier 1, carries to VI).
-- ============================================================================
Config = {}

Config.Debug = false
EOF

# ---- server bridge + logic ------------------------------------------------
if [ "$SERVER" = 1 ]; then
cat > "$DIR/bridge/sv_framework.lua" <<EOF
-- ============================================================================
-- $RES/bridge/sv_framework.lua
--
-- Framework adapter (server). The ONLY file in this resource that calls
-- qbx_core / framework exports or server-side game natives. server/main.lua
-- calls Bridge.* only, so its logic ports to GTA VI by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Bridge = {}

-- Stable per-character id, or nil.
function Bridge.GetCitizenId(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if not ok or not p then return nil end
    return p.PlayerData and p.PlayerData.citizenid or nil
end

-- Notify a player.
function Bridge.Notify(src, title, msg, t)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = msg, type = t or 'inform',
    })
end
EOF
cat > "$DIR/server/main.lua" <<EOF
-- ============================================================================
-- $RES/server/main.lua
--
-- Pure logic. Calls Bridge.* (bridge/sv_framework.lua) for all framework /
-- native access. No direct framework / native calls here (§6 gate).
-- ============================================================================

-- TODO: implement. Example:
-- RegisterNetEvent('$RES:doThing', function()
--     local src = source
--     local cid = Bridge.GetCitizenId(src)
--     if not cid then return end
--     Bridge.Notify(src, 'gtarp $NAME', 'hello from the server', 'success')
-- end)
EOF
fi

# ---- client bridge + logic ------------------------------------------------
if [ "$CLIENT" = 1 ]; then
cat > "$DIR/bridge/cl_game.lua" <<EOF
-- ============================================================================
-- $RES/bridge/cl_game.lua
--
-- Game adapter (client). The ONLY file in this resource that calls GTA
-- natives or ox_lib notify. client/main.lua calls Game.* only, so its logic
-- ports to GTA VI by rewriting THIS FILE.
-- See docs/GTA6-READINESS.md (Section 3, the bridge pattern).
-- ============================================================================

Game = {}

-- Local player position as {x,y,z}.
function Game.GetPlayerCoords()
    local p = GetEntityCoords(PlayerPedId())
    return { x = p.x, y = p.y, z = p.z }
end

-- Notify the local player.
function Game.Notify(opts)
    lib.notify(opts)
end
EOF
cat > "$DIR/client/main.lua" <<EOF
-- ============================================================================
-- $RES/client/main.lua
--
-- Pure logic. Calls Game.* (bridge/cl_game.lua) for all native access.
-- No direct natives / ox_lib here (§6 gate).
-- ============================================================================

-- TODO: implement.
EOF
fi

# ---- optional sql stub ----------------------------------------------------
if [ "$WITH_DB" = 1 ]; then
  NEXT="$(ls "$REPO/sql" 2>/dev/null | grep -oE '^[0-9]{4}' | sort -n | tail -1)"
  NEXT="$(printf '%04d' $(( 10#${NEXT:-0} + 1 )))"
  cat > "$REPO/sql/${NEXT}_${NAME}.sql" <<EOF
-- ${NEXT}_${NAME}.sql — tables for gtarp_$NAME. Apply after the qbx base schema.
-- gtarp_-prefixed per the table-naming convention (see docs/GTA6-READINESS.md
-- history — an unprefixed table silently collided with a recipe resource once).
CREATE TABLE IF NOT EXISTS \`gtarp_${NAME}\` (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(64) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gtarp_${NAME}_citizenid (citizenid)
);
EOF
  echo "  + sql/${NEXT}_${NAME}.sql"
fi

echo "Created resources/[custom]/$RES"
echo
echo "NEXT:"
echo "  1. Add to custom.cfg:  ensure $RES"
echo "  2. Implement logic in server/ + client/; keep natives in bridge/."
echo "  3. Verify §6 gate:  grep -rn 'qbx_core|\\.Functions\\.|PlayerData|ox_lib:notify|AddBlipFor|GetEntityCoords|PlayerPedId|GetGameTimer' resources/[custom]/$RES/server resources/[custom]/$RES/client"
