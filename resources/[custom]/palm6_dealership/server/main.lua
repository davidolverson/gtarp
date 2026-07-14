-- ============================================================================
-- palm6_dealership/server/main.lua
--
-- Validates the canonical catalog (shared/catalog.lua) at boot and exposes a
-- summary export. This resource has no runtime game behaviour — the catalog is
-- consumed at DEPLOY time by tools/patch-vehicle-prices.sh, which rewrites the
-- live qbx_core vehicle prices. Booting it here is purely a fail-fast guard: if
-- the catalog is malformed, the server log says so loudly instead of the patch
-- silently producing garbage.
-- ============================================================================

local function validate()
    assert(type(Catalog) == 'table', 'Catalog table missing')
    assert(type(Catalog.TierPrices) == 'table', 'Catalog.TierPrices missing')
    assert(type(Catalog.Vehicles) == 'table', 'Catalog.Vehicles missing')

    for tier, price in pairs(Catalog.TierPrices) do
        assert(math.type(price) == 'integer' and price > 0,
            ('tier %s: price must be a positive integer (got %s)'):format(tier, tostring(price)))
    end

    local seen = {}
    for i, v in ipairs(Catalog.Vehicles) do
        assert(type(v.model) == 'string' and v.model ~= '',
            ('vehicle #%d: model must be a non-empty string'):format(i))
        assert(not seen[v.model], ('duplicate model in catalog: %s'):format(v.model))
        seen[v.model] = true
        assert(Catalog.TierPrices[v.tier] ~= nil,
            ('vehicle %s: unknown tier %s'):format(v.model, tostring(v.tier)))
        assert(v.shop == 'pdm' or v.shop == 'luxury',
            ('vehicle %s: shop must be pdm or luxury (got %s)'):format(v.model, tostring(v.shop)))
    end
end

---Catalog summary: counts by tier and by shop, for devtest and the economy scoreboard.
local function summarize()
    local byTier, byShop, total = {}, { pdm = 0, luxury = 0 }, 0
    for _, v in ipairs(Catalog.Vehicles) do
        byTier[v.tier] = (byTier[v.tier] or 0) + 1
        byShop[v.shop] = (byShop[v.shop] or 0) + 1
        total = total + 1
    end
    return { total = total, byTier = byTier, byShop = byShop }
end

exports('GetSummary', function()
    return summarize()
end)

---Flat model→price map, so a future runtime consumer (or a Lua-based patch) can
---read intended prices without re-deriving the tier join.
exports('GetPriceMap', function()
    local out = {}
    for _, v in ipairs(Catalog.Vehicles) do
        out[v.model] = Catalog.TierPrices[v.tier]
    end
    return out
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    validate() -- fail-fast: a bad catalog crashes this resource, not the patch
    local s = summarize()
    print(('[palm6_dealership] catalog online — %d vehicles (pdm=%d, luxury=%d), %d tiers'):format(
        s.total, s.byShop.pdm, s.byShop.luxury,
        (function() local n = 0; for _ in pairs(Catalog.TierPrices) do n = n + 1 end return n end)()
    ))
end)
