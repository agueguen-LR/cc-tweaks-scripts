---@module "services"
---@author agueguen-LR
---@license MIT

local args = { ... }

local command = args[1]

--- Calls a craftd function taking a single service name.
---@param func fun(name: string): boolean, string?
local function call1(func)
	local name = args[2]
	assert(name, "Missing service name")

	local ok, err = func(name)

	if not ok then
		printError(err)
	end
end

--- Calls a craftd function taking a service name and an optional path.
---@param func fun(name: string, path?: string): boolean, string?
local function call2(func)
	local name = args[2]
	assert(name, "Missing service name")

	local path = args[3]

	local ok, err = func(name, path)

	if not ok then
		printError(err)
	end
end

--- Prints every known service.
local function listServices()
	local services = craftd.list()

	local names = {}

	for name in pairs(services) do
		table.insert(names, name)
	end

	table.sort(names)

	print("Services:")

	for _, name in ipairs(names) do
		local service = services[name]

		print(("- %s"):format(name))
		print(("    Config : %s"):format(service.config))
		print(("    Runtime: %s"):format(service.runtime))
		print(("    Path   : %s"):format(service.path))
	end
end

local commands = {
	list = listServices,

	start = function()
		call1(craftd.start)
	end,

	stop = function()
		call1(craftd.stop)
	end,

	enable = function()
		call2(craftd.enable)
	end,

	disable = function()
		call1(craftd.disable)
	end,

	remove = function()
		call1(craftd.remove)
	end,
}

if command and commands[command] then
	commands[command]()
else
	print("CraftKit Service Manager")
	print()
	print("Usage:")
	print("  services list")
	print("  services start <name>")
	print("  services stop <name>")
	print("  services enable <name> [path]")
	print("  services disable <name>")
	print("  services remove <name>")
	print()
	print("Notes:")
	print("  - 'enable' without a path re-enables an existing service.")
	print("  - 'remove' permanently deletes a service from configuration.")
end
