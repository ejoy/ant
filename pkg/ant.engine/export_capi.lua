local platform = require "bee.platform"

local export = {}

local luaforward = require "luaforward"
local ext = platform.os == "windows" and ".dll" or ".so"

function export.lua(localpath)
	if not localpath then
		local sys = require "bee.sys"
		localpath = sys.exe_path():remove_filename():string()
	end
	localpath = localpath .. "lua54" .. ext

	local init_func, err = package.loadlib(localpath, "luaapi_init")
	if not init_func then
		log.info("Load init_lua() from " .. localpath .. " failed : ", err)
	else
		luaforward.register(init_func)
		log.info("Export Lua API to " .. localpath)
	end
end

return export