local util = {}; util.__index = util

local fs = require "filesystem"

local default_setting = {}

local thispkg = fs.path "/pkg/ant.default_settings"
local platforms = {"ios", "mac", "window", "android"}

local function rawtable(filepath)
    local env = {}
	local r = assert(fs.loadfile(filepath, "t", env))
	r()
	return env
end

for _, plat in ipairs(platforms) do
    local cfg = thispkg / plat / "config.lua"
    default_setting[plat] = rawtable(cfg)
end

function util.default_setting(plat)
    return default_setting[plat]
end

function util.read_config(filepath)
    return rawtable(filepath)
end

return util