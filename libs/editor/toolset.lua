local fs = require "filesystem"

local PATH = "ant"

local toolset = {}

local default_toolset = {
	lua = "lua.exe",
	shaderc = "shadercRelease.exe",
}

function toolset.load_config()
	local home = fs.personaldir()
	local toolset_path = string.format("%s/%s/toolset.lua", home, PATH)
	local ret = {}
	local f,err = loadfile(toolset_path, "t", ret)
	if f then
		f()
	end
	return ret
end

local function home_path()
	local home = fs.personaldir()
	local home_path = home .. "/" .. PATH
	local attrib = fs.attributes(home_path)
	if not attrib then
		assert(fs.mkdir(home_path))
	end
	assert(attrib.mode == "directory")
	return home_path
end

function toolset.save_config(path)
	local home_path = home_path()
	local f = io.open(home_path .. "/toolset.lua", "wb")
	for k,v in pairs(path or toolset.path) do
		f:write(string.format("%s = %q\n", k,v))
	end
	f:close()
end

toolset.path = setmetatable(toolset.load_config(), { __index = default_toolset })
toolset.homedir = home_path()

return toolset
