-- ============================================================================
-- palm6_protection/client/main.lua
--
-- Fallback point dispatch, used ONLY when qbx_police's own dispatch is absent.
-- bridge/sv_framework.lua fans a `palm6_protection:dispatch` to on-duty cops as
-- a degraded-state fallback; without this handler that alert was silently
-- dropped. Renders a short-range blip + notify, exactly like palm6_drugs /
-- palm6_robbery / palm6_counterfeit. Calls Game.* only (bridge pattern).
-- ============================================================================

RegisterNetEvent('palm6_protection:dispatch', function(d)
    if not d or not d.coords then return end
    Game.ShowDispatchBlip(d.coords, d.label or 'Suspected extortion in progress', 60)
    Game.Notify({ title = 'Dispatch', description = d.label or 'Suspected extortion in progress.', type = 'inform' })
end)
