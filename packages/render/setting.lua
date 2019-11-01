local setting = {}
local fs        = require "filesystem"
local platform  = require "platform"
local platOS    = platform.OS

local function is_hw_support_depth_sample()
	if platOS == "iOS" then
		local iosinfo = import_package "ant.ios"
		local a_series = iosinfo.cpu:lower():match "apple a(%d)"
		if a_series then
			local num = tonumber(a_series)
			return num > 8
		end
    end
    return true
end

function setting.read_setting(linkconfig)
    local function rawtable(path)
		local env = {}
		fs.loadfile(path, "t", env)()
		return env
    end
    
    local s = rawtable(linkconfig)
    
    local graphic = s.graphic
    if graphic.shadow.type == "inv_z" and not is_hw_support_depth_sample() then
       graphic.shadow.type = "linear"
    end
    return s
end

function setting.init(linkconfig)
    setting.setting = setting.read_setting(linkconfig)
end

return setting