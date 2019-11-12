local m = {}
local platform  = require "platform"
local fs = require "filesystem"
local settings = import_package "ant.settings".create((fs.path "settings"):localpath(), "r")

local function is_hw_support_depth_sample()
    if platform.OS == "iOS" then
        local iosinfo = import_package "ant.ios"
        local a_series = iosinfo.cpu:lower():match "apple a(%d)"
        if a_series then
            local num = tonumber(a_series)
            return num > 8
        end
    end
    return true
end

function m.init()
    local os = platform.OS:lower()
    settings:use(os)
    if settings:get 'graphic/shadow/type' == 'inv_z' and not is_hw_support_depth_sample() then
        settings:set('_'..os..'/graphic/shadow/type', 'linear')
    end
end

function m.get()
    return settings:data()
end

return m
