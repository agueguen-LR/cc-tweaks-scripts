---@module "install"
---@author agueguen-LR
---@license MIT

--- CraftKit installer.
---
--- This module provides an installer for CraftKit, my extensions and additions for base CraftOS from CC: Tweaked.
---
---
---@see https://github.com/agueguen-LR/CraftKit

if shell.dir() ~= "" then
	printError("WARNING: Install script has not been called in the root directory; unexpected errors could arise.")
end

local completion_choice = require("cc.completion").choice

--- Base URL used to retrieve files from the GitHub repository.
---@type string
local github_link_prefix = "https://raw.githubusercontent.com/agueguen-LR/CraftKit/main/"
--- Install path prefix
---@type string
local install_path_prefix = "/CraftKit/"

--- List of scripts to install.
---@type table<string>
local available_scripts = {
	"startup",
	"bin/services",
	"sbin/craftd",
	"lib/fsutil",
}

--- Prompts the user to select one option from a list.
---
--- The prompt supports ComputerCraft's built-in tab completion.
---
---@param prompt string Text displayed before the choices.
---@param choices table<string, any> Available choices mapped to their values.
---@return string choice The selected choice.
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
---@param path ccTweaked.fs.path Local filesystem path to save the file.
---@return boolean success Whether the file was successfully downloaded.
local function download(url, path)
	print("Downloading " .. url .. " to " .. path .. "...")
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

--- Main installer entry point.
for _, script in pairs(available_scripts) do
	local link = github_link_prefix .. script .. ".lua"
	local path = install_path_prefix .. script .. ".lua"
	if not download(link, path) then
		handle_error("Failed to download " .. script, {
			func = download,
			args = { link, path },
		})
	end
end

settings.define("craftkit.path", {
	description = "Path to CraftKit installation",
	type = "string",
	default = "/CraftKit",
})
settings.set("craftkit.path", install_path_prefix)
settings.save()

local file = assert(fs.open("/startup.lua", "w"))
file.write('require(settings.get("craftkit.path") .. "/startup")')
file.close()

shell.run(install_path_prefix .. "startup")
