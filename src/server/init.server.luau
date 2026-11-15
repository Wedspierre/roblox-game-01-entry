-- NEON VOID server entry: start the authoritative game server.
-- All game logic lives in GameServer; this file only boots it.
-- NOTE: Rojo turns this init file into the "Server" Script itself, so
-- GameServer is a CHILD of this script (ServerScriptService.Server
-- .GameServer), not a sibling under ServerScriptService. Requiring it
-- through script.Parent silently returns nil and kills the server.

local GameServer = require(script.GameServer)

GameServer.start()
