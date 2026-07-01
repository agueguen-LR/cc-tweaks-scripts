require("lib.utils")

local wireless = get_wireless()
local monitor = peripheral.find("monitor")
local chatbox = peripheral.find("chat_box")
local server_channel = 1

wireless.open(server_channel)

while true do
	local received_message = wait_for_message(server_channel)
	print("Received message from client: " .. received_message)
	if string.find(received_message, "ERROR:") then
		monitor.setTextColor(colors.red)
		writeLine(monitor, received_message, colors.red)
		monitor.setTextColor(colors.white)
		chatbox.sendMessage(received_message)
	else
		writeLine(monitor, received_message, colors.white)
	end
end
