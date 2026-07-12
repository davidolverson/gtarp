-- ============================================================
--  prop_spawn  —  dev-only test helper
--  FiveM has no native /object command, so this gives you one.
--  ensure this AFTER your prop resource. Remove it from production.
-- ============================================================
fx_version 'cerulean'
game 'gta5'

author 'YourName'
version '1.0.0'
description 'Dev command to spawn/clear custom props for testing'

client_script 'client.lua'
