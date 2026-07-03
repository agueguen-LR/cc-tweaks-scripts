local fs = require(settings.get("craftkit.path") .. ".lib.fs")

fs.ensureDir("/etc")
fs.ensureDir("/etc/craftkit")

fs.ensureDir("/var")
fs.ensureDir("/var/log")
fs.ensureDir("/var/run")

fs.ensureDir("/services")

fs.ensureFile("/etc/craftkit/services.lua", "return {}\n")
