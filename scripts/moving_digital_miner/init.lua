require("lib.utils")

local name = "DigitalMinerTurtle"
local wireless = get_wireless()
local server_channel = 1
local turtle_channel = 2

local turtle_info = {
	name = name,
	wireless = wireless,
	server_channel = server_channel,
	device_channel = turtle_channel,
}

wireless.open(2)

function turnAround()
	turtle.turnRight()
	turtle.turnRight()
end

function place_digital_miner()
	place(dm, turtle_info, turtle.placeUp)
	os.sleep(0.2)

	local miner = peripheral.wrap("top")
	miner.start()

	move(2, turtle_info, turtle.forward)
	move(1, turtle_info, turtle.up)
	place(qe, turtle_info, turtle.placeUp)
	move(1, turtle_info, turtle.down)
	move(2, turtle_info, turtle.back)

	turtle.turnRight()
	move(2, turtle_info, turtle.forward)
	place(qe, turtle_info, turtle.placeUp)

	turtle.turnRight()
	move(1, turtle_info, turtle.forward)
	turnAround()

	place(ds, turtle_info, turtle.place)

	turnAround()
	move(30, turtle_info, turtle.forward)
	dig(turtle_info, turtle.dig)
	move(1, turtle_info, turtle.forward)
	dig(turtle_info, turtle.digUp)

	turtle.turnRight()
	move(2, turtle_info, turtle.forward)
	turtle.turnRight()
	move(32, turtle_info, turtle.forward)

	local pos = locate()
	if pos then
		send(turtle_info, "Digital Miner placed and started. Location: " .. pos, false)
	else
		complain(turtle_info, "Digital Miner placed and started, but I couldn't determine my location.", 3)
	end
end

function watch_ores_left()
	local miner = peripheral.wrap("top")
	local oldLeft = miner.getToMine()
	while miner.getToMine() > 0 do
		os.sleep(3)
		local newLeft = miner.getToMine()
		if newLeft == oldLeft then
			complain(turtle_info, "Digital Miner isn't progressing", 5)
		else
			oldLeft = newLeft
			send(turtle_info, "Digital Miner has " .. newLeft .. " ores left to mine", false)
		end
	end
end

function pickup_and_go_next()
	dig(turtle_info, turtle.digUp)
	move(2, turtle_info, turtle.forward)
	move(1, turtle_info, turtle.up)
	dig(turtle_info, turtle.digUp)
	move(1, turtle_info, turtle.down)
	move(30, turtle_info, turtle.forward)
end

function startup()
	os.sleep(3)
	if peripheral.isPresent("top") then
		local whatsup = peripheral.getType("top")
		send(turtle_info, "Starting up, " .. whatsup .. " is above, attempting to continue naturally", false)
	else
		complain(turtle_info, "Starting up, digital miner is not above, cannot reliably determine situation", 5)
	end
end

startup()
while true do
	watch_ores_left()
	pickup_and_go_next()
	place_digital_miner()
end
