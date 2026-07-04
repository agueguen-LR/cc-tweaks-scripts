---@module "craftd"
---@author agueguen-LR
---@license MIT

--- CraftKit Service Daemon (craftd)
--
-- Manages the lifecycle of CraftKit services. Services are configured
-- persistently through `services.lua` and executed cooperatively using
-- Lua coroutines.
--
-- Each service consists of two distinct states:
--   • Configuration state (enabled / disabled)
--   • Runtime state (running / stopped / crashed)
--
-- The daemon forwards every system event to each running service,
-- allowing services to cooperatively yield and resume as events occur.

local craftkit_path = settings.get("craftkit.path")
assert(craftkit_path, "craftkit.path setting is not defined")

local fsutil = require(craftkit_path .. "lib.fsutil")

local config_path = craftkit_path .. "/etc/services.lua"

fsutil.ensureDir(craftkit_path .. "/etc")
fsutil.ensureFile(config_path, "return {}\n")

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

--- Persistent service configuration states.
---@enum CraftdConfigStatus
local ConfigStatus = {
	ENABLED = "enabled",
	DISABLED = "disabled",
}

--- Runtime service states.
---@enum CraftdRuntimeStatus
local RuntimeStatus = {
	RUNNING = "running",
	STOPPED = "stopped",
	CRASHED = "crashed",
}

--- Persistent service configuration.
---@class CraftdServiceConfig
---@field path string Path to the service program.
---@field status CraftdConfigStatus Persistent service state.

--- Runtime representation of a service.
---@class CraftdRunningService
---@field coroutine thread Service coroutine.
---@field path string Path to the service program.
---@field status CraftdRuntimeStatus Runtime service state.

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

--- Persistent service configuration loaded from disk.
--
-- This table is serialized back to `services.lua` whenever the
-- configuration changes.
--
---@type table<string, CraftdServiceConfig>
local enabled = dofile(config_path)

assert(type(enabled) == "table", "services.lua must return a table")

--- Currently running services.
--
-- Keys correspond to service names.
--
---@type table<string, CraftdRunningService>
local running = {}

--------------------------------------------------------------------------------
-- Service lifecycle
--------------------------------------------------------------------------------

--- Starts a configured service.
--
-- The service must exist in the persistent configuration.
--
-- The service program is executed inside an isolated environment
-- inheriting from `_G` and wrapped in a coroutine. The coroutine is
-- resumed once to allow initialization before entering its event loop.
--
-- Services are expected to cooperatively yield while waiting for
-- events.
--
---@param name string Service name.
---@return boolean success
---@return string? err
local function startService(name)
	local config = enabled[name]

	if not config then
		return false, "service does not exist"
	end

	local runtime = running[name]

	if runtime and runtime.status == RuntimeStatus.RUNNING then
		return false, "already running"
	end

	if not fs.exists(config.path) then
		return false, "service does not exist"
	end

	--- Service execution environment.
	-- Inherits the global environment.
	local env = {}
	setmetatable(env, { __index = _G })

	local fn, err = loadfile(config.path, "t", env)

	if not fn then
		return false, err or ("failed to load service: " .. config.path)
	end

	local co = coroutine.create(fn)

	runtime = {
		coroutine = co,
		path = config.path,
		status = RuntimeStatus.RUNNING,
	}

	running[name] = runtime

	local ok, resumeErr = coroutine.resume(co)

	if not ok then
		runtime.status = RuntimeStatus.CRASHED

		printError(("Service '%s' crashed during startup:\n%s"):format(name, tostring(resumeErr)))

		return false, resumeErr
	end

	if coroutine.status(co) == "dead" then
		runtime.status = RuntimeStatus.STOPPED
	end

	return true
end

--- Stops a running service.
--
-- Lua coroutines cannot be forcibly terminated. Removing the runtime
-- record simply unregisters the service from the daemon so it will no
-- longer receive events.
--
-- Future versions may implement graceful shutdown by delivering a
-- dedicated stop event before unregistering the service.
--
---@param name string Service name.
---@return boolean success
---@return string? err
local function stopService(name)
	local runtime = running[name]

	if not runtime or runtime.status ~= RuntimeStatus.RUNNING then
		return false, "not running"
	end

	running[name] = nil

	return true
end

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

--- Writes the persistent service configuration to disk.
--
-- The configuration is serialized as a Lua table and reloaded with
-- `dofile()` during daemon startup.
local function saveServices()
	local file = assert(fs.open(config_path, "w"))

	file.write("return " .. textutils.serialize(enabled))
	file.close()
end

--- Disables a service.
--
-- The service configuration is updated on disk and the service is
-- stopped if it is currently running.
--
---@param name string Service name.
---@return boolean success
---@return string? err
local function disableService(name)
	local service = enabled[name]

	if not service then
		return false, "service does not exist"
	end

	service.status = ConfigStatus.DISABLED

	saveServices()

	stopService(name)

	return true
end

--- Removes a service completely from persistent configuration.
--
-- This deletes the service from disk and stops it if it is running.
-- This operation is irreversible unless the service is re-added manually.
--
---@param name string Service name.
---@return boolean success
---@return string? err
local function removeService(name)
	local service = enabled[name]

	if not service then
		return false, "service does not exist"
	end

	-- Stop runtime instance if running
	stopService(name)

	-- Remove from persistent config
	enabled[name] = nil

	saveServices()

	return true
end

--- Enables a service.
--
-- If the service already exists, its configuration is updated.
-- Otherwise, a new configuration entry is created.
--
-- The service is immediately started after being enabled.
--
---@param name string Service name.
---@param path? string Optional path to the service program. Required if the service does not already exist.
---@return boolean success
---@return string? err
local function enableService(name, path)
	local service = enabled[name]

	if service then
		service.status = ConfigStatus.ENABLED

		-- Allow updating the path if one is supplied.
		if path then
			service.path = path
		end
	else
		if not path then
			return false, "missing service path"
		end

		service = {
			status = ConfigStatus.ENABLED,
			path = path,
		}

		enabled[name] = service
	end

	saveServices()

	return startService(name)
end

--------------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------------

--- Lists every known service.
--
-- This combines the persistent configuration table with the runtime
-- state table so both configured and manually started services are
-- visible.
--
---@return table<string, table>
local function listServices()
	local list = {}
	local names = {}

	for name in pairs(enabled) do
		names[name] = true
	end

	for name in pairs(running) do
		names[name] = true
	end

	for name in pairs(names) do
		local config = enabled[name]
		local runtime = running[name]

		list[name] = {
			config = config and config.status or ConfigStatus.DISABLED,
			runtime = runtime and runtime.status or RuntimeStatus.STOPPED,
			path = config and config.path or runtime.path,
		}
	end

	return list
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- CraftKit service manager API.
_G.craftd = {
	start = startService,
	stop = stopService,
	enable = enableService,
	disable = disableService,
	remove = removeService,
	list = listServices,
}

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

--- Starts every enabled service from the persistent configuration.
for name, service in pairs(enabled) do
	if service.status == ConfigStatus.ENABLED then
		local ok, err = startService(name)

		if not ok then
			printError(("Failed to start service '%s': %s"):format(name, tostring(err)))
		end
	end
end

--------------------------------------------------------------------------------
-- Daemon
--------------------------------------------------------------------------------

--- CraftKit daemon event dispatcher.
--
-- Every event received from `os.pullEventRaw()` is forwarded to each
-- running service coroutine.
--
-- Services execute cooperatively and are expected to yield after
-- processing events. Runtime errors mark the service as `RuntimeStatus.CRASHED`,
-- while services that return naturally become `RuntimeStatus.STOPPED`.
local function craftd_main_loop()
	while true do
		local event = { os.pullEventRaw() }

		for name, service in pairs(running) do
			if service.status == RuntimeStatus.RUNNING then
				local ok, err = coroutine.resume(service.coroutine, table.unpack(event))

				if not ok then
					service.status = RuntimeStatus.CRASHED

					printError(("Service '%s' crashed:\n%s"):format(name, tostring(err)))
				elseif coroutine.status(service.coroutine) == "dead" then
					service.status = RuntimeStatus.STOPPED
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Runtime
--------------------------------------------------------------------------------

-- Start the CraftKit daemon and launch a shell in parallel. The shell runs in a separate coroutine, allowing users to interact with the system while services are managed in the background.
parallel.waitForAny(craftd_main_loop, function()
	while true do
		shell.run("/rom/programs/shell.lua")
	end
end)
