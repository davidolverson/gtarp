-- 0049_turf_identity_reset.sql — reconcile palm6_turf.owner_gang after the
-- gang-identity change (turf now keys on the PLAYER-RUN gang palm6_gangs.name,
-- not the qbx STATIC gang). Any owner_gang written under the OLD identity is a
-- name that will essentially never match a palm6_gangs name, so it would show
-- phantom rows on the season/ganginfo turf ladders and could be inherited by a
-- player who founds a gang with that exact name. This releases such turf.
--
-- IDEMPOTENT BY DESIGN — it is embedded in palm6_dbmigrate, which re-runs every
-- boot with NO ledger, so it MUST be safe to re-run: it only nulls turf whose
-- owner_gang is NOT a currently-existing palm6_gangs name. After the cutover,
-- legitimately-captured turf (a real palm6_gangs name) is untouched; and as a
-- bonus it auto-releases turf whose owning gang later disbands. Also embedded
-- in palm6_dbmigrate for prod, since CI never touches the DB.

UPDATE `palm6_turf`
   SET `owner_gang` = NULL, `captured_by` = NULL, `captured_at` = NULL
 WHERE `owner_gang` IS NOT NULL
   AND `owner_gang` NOT IN (SELECT `name` FROM `palm6_gangs`);
