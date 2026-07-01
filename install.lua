if shell.dir() ~= "" then
	printError("WARNING: Install script has not been called in the root directory; unexpected errors could arise.")
end

local completion_choice = require("cc.completion").choice

local github_link_prefix = "https://raw.githubusercontent.com/agueguen-LR/cc-tweaks-scripts/main/"

local available_scripts = {
	server = true,
	moving_digital_miner = true,
}

local function prompt_choice(prompt, choices)
	local names = {}

	for name in pairs(choices) do
		table.insert(names, name)
	end

	while true do
		print(prompt)
		for _, name in ipairs(names) do
			print("-", name)
		end
		write("> ")

		local choice = read(nil, nil, function(partial)
			return completion_choice(partial, names)
		end)

		if choices[choice] then
			return choice
		end

		printError("Invalid choice: " .. tostring(choice) .. ".")
	end
end

local function handle_error(err, retry)
	printError("An error occurred: " .. tostring(err))

	local options = {
		try_again = function()
			return retry.func(table.unpack(retry.args))
		end,

		restart_install = function()
			shell.run("install")
			shell.exit()
		end,

		give_up = function()
			error("Install failed.")
		end,
	}

	local choice = prompt_choice("What should we do?", options)
	return options[choice]()
end

local function download(url, path)
	if fs.exists(path) then
		return true
	end

	local response = http.get(url)
	if not response then
		return false
	end

	local file = assert(fs.open(path, "w"))
	file.write(response.readAll())
	file.close()
	response.close()

	return true
end

local function download_chosen_script(chosen_script)
	fs.makeDir("/lib")

	if not download(github_link_prefix .. "lib/utils.lua", "/lib/utils.lua") then
		return handle_error("Failed to download lib/utils.lua.", {
			func = download_chosen_script,
			args = { chosen_script },
		})
	end

	fs.makeDir("/scripts/" .. chosen_script)

	if
		not download(
			github_link_prefix .. "scripts/" .. chosen_script .. "/init.lua",
			"/scripts/" .. chosen_script .. "/init.lua"
		)
	then
		return handle_error("Failed to download " .. chosen_script .. "/init.lua.", {
			func = download_chosen_script,
			args = { chosen_script },
		})
	end
end

local function write_startup(chosen_script)
	local startup_file = assert(fs.open("startup.lua", "w"))

	startup_file.write(('require("scripts.%s")'):format(chosen_script))
	startup_file.close()
end

local chosen_script = prompt_choice("What script do you wish to install?\nAvailable scripts:", available_scripts)

download_chosen_script(chosen_script)
write_startup(chosen_script)

print("Success! You can reboot this computer to start the script.")
