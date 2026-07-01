--- Utility functions for CC: Tweaks
---@module "utils"
---@author agueguen-LR
---@license MIT

--- Returns the device's current coordinates as a string, or nil if it can't be located
---@return string|nil
function Locate()
	local x, y, z = gps.locate(30)
	if x == nil then
		return nil
	end
	return string.format("%d %d %d", x, y, z)
end

--- Prompts the user to select one option from a list.
---
--- Supports ComputerCraft's built-in tab completion and repeats until a
--- valid choice is entered.
---
---@param prompt string Text displayed before reading input.
---@param choices table<string, any> Available choices mapped to any value.
---@param show_choices? boolean Whether to print the list of choices. Defaults to true.
---@return string choice The selected choice name.
function Prompt_Choice(prompt, choices, show_choices)
	if show_choices == nil then
		show_choices = true
	end

	local names = {}

	for name in pairs(choices) do
		table.insert(names, name)
	end

	table.sort(names)

	while true do
		print(prompt)

		if show_choices then
			for _, name in ipairs(names) do
				print("-", name)
			end
		end

		write("> ")

		local choice = read(nil, nil, function(partial)
			return require("cc.completion").choice(partial, names)
		end)

		if choices[choice] ~= nil then
			return choice
		end

		printError(("Invalid choice: %s."):format(tostring(choice)))
	end
end

--- Waits until a peripheral matching the given predicate is available.
---
--- Repeatedly calls `find_func` until it returns a peripheral. If a name is
--- provided, a waiting message is displayed while no matching peripheral is
--- found.
---
---@generic T
---@param find_func fun(): T? Function returning the desired peripheral, or nil if unavailable.
---@param name? string Human-readable peripheral name to display while waiting. If omitted, no status is displayed.
---@return T peripheral The matching peripheral.
function Wait_For_Peripheral(find_func, name)
	while true do
		local peripheral = find_func()

		if peripheral then
			return peripheral
		end

		if name then
			term.clear()
			term.setCursorPos(1, 1)

			print(("No %s detected."):format(name))
			print(("Please connect a %s."):format(name))
			print()
			print("Waiting...")
		end

		os.pullEvent("peripheral")
	end
end

--- Waits for a message on the given channel and returns it
---@param channel number
---@return string
function Wait_For_Message(channel)
	local _, _, found_channel, _, message

	repeat
		_, _, found_channel, _, message = os.pullEvent("modem_message")
	until found_channel == channel

	return message
end

--- Sends a message on the given channel, and prints it to the console
---@param info table contains the sender's name, wireless peripheral, target channel, and sender's own reply channel
---@param message string
---@param error boolean
function Send(info, message, error)
	if error then
		message = "ERROR: " .. message
	end
	info.wireless.transmit(info.server_channel, info.device_channel, message)
	print("Sent to server: " .. message)
end

--- Sends an error message every `interval` seconds, including the device's current position if it can be located
---@param info table contains the sender's name, wireless peripheral, target channel, and sender's own reply channel
---@param message string
---@param interval number
function Complain(info, message, interval)
	while true do
		local pos = locate()

		local msg = info.name .. ". " .. message
		if pos then
			msg = msg .. ". I'm at: " .. pos
		end

		send(info, msg, true)

		if not pos then
			locate() -- Retry to get position if it failed before
		end

		os.sleep(interval)
	end
end
