# CraftKit

Extensions and additions on the base CraftOS shell, to provide a more user-friendly experience and higher level commands for interacting with ingame devices.

Tested with versions:
 - Minecraft 1.21.1
 - Neoforge 21.1.228
 - CC: Tweaked 1.117.1
 - Advanced Peripherals 0.7.61b
 - Mekanism (Moving digital miner script) 10.7.19

On [All The Mods 10](https://www.curseforge.com/minecraft/modpacks/all-the-mods-10) version 7.0.

## Usage

Get the installer and run it:

```bash
wget https://raw.githubusercontent.com/agueguen-LR/cc-tweaks-scripts/main/install.lua
install
```

> [!WARNING]
> The installer expects to be called within the root directory, on a blank computer (only rom/ folder).
> Anything else is untested, and could cause unexpected errors

## Development

### Writing code and testing

To be able to quickly test your code ingame, I recommend creating a symbolic link to your minecraft world's computer folder, so you can edit the files in your IDE and have them immediately and automatically updated ingame on the computer with the selected id.

```bash
  cd <path-to-minecraft>/saves/<your-test-world>/computercraft/computer 
  ln -s <path-to-this-repo> <ingame-computer-id>
```

### LuaLS LSP support

The following section was made with neovim in mind, but should be applicable to any editor that uses the [Lua Language Server](https://github.com/LuaLS/lua-language-server) directly. I haven't looked into VSCode, but you can find decent information for it specifically with some internet searching.


To get CC: Tweaks LuaLS LSP support, with references and definitions, you can make a lsp-rom/ folder containing the lua files from the [source code](https://github.com/cc-tweaked/CC-Tweaked/tree/v1.20.1-1.117.1/projects/core/src/main/resources/data/computercraft/lua/rom) to and a lsp-globals/ folder containing extra documentation courtesy of [github.com/nvim-computercraft/lua-ls-cc-tweaked](https://github.com/nvim-computercraft/lua-ls-cc-tweaked/tree/main/library). LuaLS should then use the provided .luarc.json file to find and use the two folders, maybe after a quick restart of the language server/IDE ;).


This website is a good tool for downloading the needed folders only: [download-directory.github.io](https://download-directory.github.io/)


There is some overlap between the two, but to have a rather complete environment, you might as well use both. Specifically, lsp-rom will allow you to read the actual source of many of the mod's modules, but doesn't contain any definitions of the global variables/functions CraftOS provides, while lsp-globals will provide those definitions (as well as definitions you'd find in lsp-rom), but doesn't have any source code.
