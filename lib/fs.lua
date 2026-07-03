local function ensureDir(path)
	if not fs.exists(path) then
		fs.makeDir(path)
	elseif not fs.isDir(path) then
		error(("'%s' exists but is not a directory"):format(path))
	end
end

local function ensureFile(path, contents)
	if fs.exists(path) then
		return
	end

	local file = fs.open(path, "w")
	if not file then
		error(("Failed to create '%s'"):format(path))
	end

	file.write(contents or "")
	file.close()
end
