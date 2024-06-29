local platform = require "bee.platform"

local luaforward = require "luaforward"
local ext = platform.os == "windows" and ".dll" or ".so"

local function export_lua()
	local sys = require "bee.sys"
	local localpath = sys.exe_path():remove_filename():string()
	localpath = localpath .. "lua54" .. ext

	local init_func, err = package.loadlib(localpath, "luaapi_init")
	if init_func then
		return luaforward.register(init_func)
	else
		return function (f, ...)
			return f(...)
		end
	end
end

return export_lua()
