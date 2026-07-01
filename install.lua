---@module "install"
---@author agueguen-LR
---@license MIT

--- ComputerCraft Tweaks scripts installer.
---
--- This module provides an interactive installer for my CC Tweaks scripts
--- collection. It allows the user to choose a script to install, downloads
--- the required dependencies from GitHub, and launches the selected script.
---
--- The installer:
--- - Ensures it is executed from the root directory.
--- - Downloads shared libraries.
--- - Downloads the selected script.
--- - Handles download failures with retry/restart/abort options.
---
---@see https://github.com/agueguen-LR/cc-tweaks-scripts

if shell.dir() ~= "" then
	printError("WARNING: Install script has not been called in the root directory; unexpected errors could arise.")
end

local completion_choice = require("cc.completion").choice

--- Base URL used to retrieve files from the GitHub repository.
---@type string
local github_link_prefix = "https://raw.githubusercontent.com/agueguen-LR/cc-tweaks-scripts/main/"

--- List of scripts available for installation.
---
--- Keys correspond to script folder names inside the repository.
---@type table<string, boolean>
local available_scripts = {
	server = true,
	moving_digital_miner = true,
}

--- Prompts the user to select one option from a list.
---
--- The prompt supports ComputerCraft's built-in tab completion.
---
---@param prompt string Text displayed before the choices.
---@param choices table<string, any> Available choices mapped to their values.
---@return string choice The selected choice name.
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

--- Handles an installation error.
---
--- Gives the user the choice to retry the failed operation, restart the
--- installation process, or abort.
---
---@param err any Error message or object.
---@param retry table Retry information.
---@field func function Function to call when retrying.
---@field args any[] Arguments passed to the retry function.
---@return any Result of the chosen action.
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

--- Downloads a file from a URL.
---
--- If the destination file already exists, the download is skipped.
---
---@param url string URL to download from.
---@param path string Local filesystem path to save the file.
---@return boolean success Whether the file was successfully downloaded.
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

--- Installs a selected script and its dependencies.
---
--- Creates the required directories, downloads shared libraries, downloads
--- the selected script, and retries on failure if requested.
---
---@param chosen_script string Name of the script to install.
---@return any result Result from the launched script.
local function download_chosen_script(chosen_script)
	-- download library utils first
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

local function create_startup_file(chosen_script)
	local file = assert(fs.open("/startup.lua", "w"))
	file.write('shell.run("bg")') -- open a shell for the user
	file.write('require("scripts/' .. chosen_script .. '")')
	file.close()
end

--- Main installer entry point.
---
--- Prompts the user for a script choice, installs it,
--- sets it as the startup script then executes it.
local chosen_script = prompt_choice("What script do you wish to install?\nAvailable scripts:", available_scripts)
download_chosen_script(chosen_script)
create_startup_file(chosen_script)
shell.run("startup")
