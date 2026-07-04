---@module "startup"
---@author "agueguen-LR"
---@license MIT
---
--- Startup script for CraftKit, following the style of CC: Tweaked's rom/startup.lua.

local completion = require("cc.shell.completion")

local craftkit_dir = settings.get("craftkit.path")

shell.setPath(shell.path() .. ":/" .. fs.combine(craftkit_dir, "bin"))

shell.setCompletionFunction(
	fs.combine(craftkit_dir, "bin/services.lua"),
	completion.build({
		completion.choice,
		{ "list", "start", "stop", "restart", "enable", "disable" },
	}, completion.file)
)

shell.run(fs.combine(craftkit_dir, "sbin/craftd.lua"))
