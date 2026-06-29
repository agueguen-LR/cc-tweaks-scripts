--- Utility functions for CC: Tweaks computers and turtles
---@module "utils"
---@author agueguen-LR

--- abbreviations for item names for select_item()
dm = "mekanism:digital_miner"
ds = "mekanism:dimensional_stabilizer"
qe = "mekanism:quantum_entangloporter"
lava = "minecraft:lava_bucket"

--- Returns the turtle's current coordinates as a string, or nil if it can't be located
---@return string
function locate()
	x, y, z = gps.locate(30)
	if x == nil then
		return nil
	end
	return string.format("%d %d %d", x, y, z)
end

--- Moves the turtle forward n times, complaining to the server if it can't
---@param n number
---@param turtle_info table contains the turtle's name, wireless peripheral, server channel, and turtle's own reply channel
---@param move_func function the turtle's move function to call (turtle.forward, turtle.up, or turtle.down)
function move(n, turtle_info, move_func)
	for _ = 1, n, 1 do
		::retry_move::
		local ok, err = move_func()
		if not ok then
			if err == "Out of fuel" then
				refuel(turtle_info)
				goto retry_move
			else
				complain(turtle_info, "Failed to move forward: " .. err, 5)
			end
		end
	end
end

--- Safely places an item, complaining to the server if it can't.
---@param item_name string
---@param turtle_info table contains the turtle's name, wireless peripheral, server channel, and reply channel
---@param place_func function -- turtle.place, turtle.placeUp, or turtle.placeDown
function place(item_name, turtle_info, place_func)
	select_item(item_name, turtle_info)

	while true do
		local ok, err = place_func()
		if ok then
			return
		end

		complain(turtle_info, "Failed to place " .. item_name .. ": " .. err, 5)
	end
end

--- Selects the turtle's first slot containing the given item name.
---@param item_name string
---@param turtle_info table contains the turtle's name, wireless peripheral, server channel, and reply channel
function select_item(item_name, turtle_info)
	for i = 1, 16 do
		local item_info = turtle.getItemDetail(i)
		if item_info and item_info.name == item_name then
			turtle.select(i)
			return
		end
	end

	complain(turtle_info, "Missing required item: " .. item_name, 5)
end

--- Safely digs a block, complaining to the server if it can't.
---@param turtle_info table contains the turtle's name, wireless peripheral, server channel, and reply channel
---@param dig_func function -- turtle.dig, turtle.digUp, or turtle.digDown
function dig(turtle_info, dig_func)
	while true do
		local ok, err = dig_func()

		if ok then
			return
		end

		complain(turtle_info, "Failed to dig: " .. err, 5)
	end
end

--- Get the first wireless modem connected to the computer
---@return peripheral
function get_wireless()
	return peripheral.find("modem", function(name, modem)
		return modem.isWireless()
	end)
end

--- Get the first wired modem connected to the computer
---@return peripheral
function get_wired()
	return peripheral.find("modem", function(name, modem)
		return not modem.isWireless()
	end)
end

--- Waits for a message on the given channel and returns it
---@param channel number
---@return string
function wait_for_message(channel)
	local event, side, found_channel, replyChannel, message, distance

	repeat
		event, side, found_channel, replyChannel, message, distance = os.pullEvent("modem_message")
	until found_channel == channel

	return message
end

--- Scrolls up and prints a message to the bottom of the monitor
---@param monitor peripheral
---@param message string
function writeLine(monitor, message)
	x, y = monitor.getSize()
	monitor.scroll(1)
	monitor.setCursorPos(1, y)
	monitor.write(message)
end

--- Sends a message to the server on the given channel, and prints it to the console
---@param info table contains the sender's name, wireless peripheral, target channel, and sender's own reply channel
---@param message string
---@param error boolean
function send(info, message, error)
	if error then
		message = "ERROR: " .. message
	end
	info.wireless.transmit(info.server_channel, info.device_channel, message)
	print("Sent to server: " .. message)
end

--- Sends an error message to the server every `interval` seconds, including the turtle's current position if it can be located
---@param info table contains the sender's name, wireless peripheral, target channel, and sender's own reply channel
---@param message string
---@param interval number
function complain(info, message, interval)
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

--- Refuels the turtle using a lava bucket if it has fuel, or does nothing if the turtle has unlimited fuel
---@param turtle_info table contains the turtle's name, wireless peripheral, server channel, and turtle's own reply channel
function refuel(turtle_info)
	local level = turtle.getFuelLevel()
	if level == "unlimited" then
		return
	end

	select_item(lava, turtle_info)
	local ok, err = turtle.refuel()
	if not ok then
		complain(turtle_info, "Failed to refuel: " .. err, 5)
	else
		send(turtle_info, turtle_info.name .. " has refueled with a lava bucket.", false)
	end
end
