---@module "server"
---@author agueguen-LR
---@license MIT

--- Server entry point.
---
--- Starts the ComputerCraft server by:
---   - Waiting for a wireless modem.
---   - Updating an optional status monitor.
---   - Running the main server loop.
---   - Providing an interactive administration console.

require("lib.utils")

--- Wait for a wireless modem to be attached.

--- Whether the server is currently accepting requests.
local server_enabled = true
--- Whether a wireless modem is currently connected.
local modem_connected = true
--- Whether a monitor is currently connected.
local monitor_connected = false

local completion_choice = require("cc.completion").choice

--- Updates the attached monitor with server status information.
---
--- If no monitor is connected, waits until one is attached.
--- If the monitor is removed while running, waits for a replacement.
local function monitor_task()
	while true do
		local monitor = Wait_For_Peripheral(function()
			return peripheral.find("monitor")
		end)

		monitor_connected = true

		while true do
			-- Monitor calls can fail if the peripheral is removed.
			-- Use pcall to recover gracefully.
			local ok = pcall(function()
				local width = monitor.getSize()

				monitor.clear()

				-- Server status on the left.
				monitor.setCursorPos(1, 1)
				monitor.write("Server: " .. (server_enabled and "Online" or "Offline"))

				-- Date and time on the right.
				local datetime = os.date("%T %A %d %B %Y", os.epoch("local") / 1000)

				monitor.setCursorPos(width - #datetime + 1, 1)
				monitor.write(datetime)
			end)

			-- Monitor was disconnected.
			if not ok then
				monitor_connected = false
				break
			end

			sleep(1)
		end
	end
end

--- Main server loop.
---
--- Handles incoming network traffic and server logic.
--- Currently only acts as a placeholder.
local function server_task()
	while true do
		local modem = Wait_For_Peripheral(function()
			return peripheral.find("modem", function(_, modem)
				return modem.isWireless()
			end)
		end)
		local modem_name = peripheral.getName(modem)

		rednet.open(modem_name)
		modem_connected = true

		while rednet.isOpen(modem_name) do
			-- serve protocols
			sleep(0.1)
		end
		modem_connected = false
	end
end

--- Interactive administration console.
---
--- Provides:
---   - A status display.
---   - A command input area.
---
--- Available commands:
---   on  - Enable the server.
---   off - Disable the server.
local function console_task()
	local command_handlers = {
		--- Enable the server.
		on = function()
			server_enabled = true
		end,

		--- Disable the server.
		off = function()
			server_enabled = false
		end,
	}

	local width, height = term.getSize()

	-- Split the terminal:
	--
	-- +----------------------+
	-- |                      |
	-- | Status area          |
	-- |                      |
	-- +----------------------+
	-- | Command input        |
	-- +----------------------+
	local status_win = window.create(term.current(), 1, 1, width, height - 3)

	local command_win = window.create(term.current(), 1, height - 2, width, 3)

	--- Redraw the status display.
	local function redraw_status()
		status_win.clear()
		status_win.setCursorPos(1, 1)

		status_win.write("Server console")

		status_win.setCursorPos(1, 3)
		status_win.write("Status: ")
		status_win.write(server_enabled and "Online" or "Offline")

		status_win.setCursorPos(1, 4)
		status_win.write("Wireless Modem: ")
		status_win.write(modem_connected and "Connected" or "Not Connected")

		status_win.setCursorPos(1, 5)
		status_win.write("Monitor: ")
		status_win.write(monitor_connected and "Connected" or "Not Connected")

		status_win.redraw()
	end

	--- Redraw the command input area.
	local function redraw_command()
		command_win.clear()
		command_win.setCursorPos(1, 1)

		command_win.write("Command:")

		command_win.setCursorPos(1, 2)
		command_win.write("> ")

		command_win.redraw()
	end

	--- Continuously updates the status display.
	local function status_task()
		while true do
			redraw_status()
			sleep(0.25)
		end
	end

	--- Handles user commands.
	local function command_task()
		while true do
			redraw_command()

			-- Redirect read() output into the command window.
			local old = term.redirect(command_win)

			command_win.setCursorPos(3, 2)
			command_win.setCursorBlink(true)

			local command_names = {}
			for name in pairs(command_handlers) do
				table.insert(command_names, name)
			end
			local command = read(nil, nil, function(partial)
				return completion_choice(partial, command_names)
			end)

			command_win.setCursorBlink(false)

			-- Restore the original terminal.
			term.redirect(old)

			local handler = command_handlers[command]

			if handler then
				handler()
			else
				command_win.clear()
				command_win.setCursorPos(1, 1)
				command_win.write("Invalid command: " .. tostring(command))

				command_win.redraw()
				sleep(1)
			end
		end
	end

	-- Run the UI components together.
	parallel.waitForAll(status_task, command_task)
end

-- Start all server components.
parallel.waitForAll(monitor_task, server_task, console_task)
