-- NEON VOID server entry: start the authoritative game server.
-- All game logic lives in GameServer; this file only boots it.

local GameServer = require(script.Parent.GameServer)

GameServer.start()
