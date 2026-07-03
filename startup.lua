---@module "startup"
---@author "agueguen-LR"
---@license MIT
---
--- Startup script for CraftKit, following the style of CC: Tweaked's rom/startup.lua.

local completion = require("cc.shell.completion")

-- Get the directory of this startup script as the base directory for CraftKit.
local tArgs = { ... }
local sDir = fs.getDir(tArgs[1])

shell.setPath(shell.path() .. ":/" .. fs.combine(sDir, "bin"))

shell.run(sDir .. "/sbin/craftd")
