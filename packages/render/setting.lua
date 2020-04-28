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

local OS = platform.OS:lower()

function m.init()
    settings:use(OS)
    if settings:get 'graphic/shadow/type' == 'inv_z' and not is_hw_support_depth_sample() then
        settings:set('_'..os..'/graphic/shadow/type', 'linear')
    end
end

function m.get()
    return settings:data()
end

function m.rawtable(os)
    os = os or OS
    settings:use(OS)
    local proxy = m.get()
    local function deepcopy(t)
        local r = {}
        for k, v in pairs(t) do
            local tt = type(v)
            if tt == "table" then
                r[k] = deepcopy(v)
            elseif tt == "userdata" then
                error("not support userdata")
            else
                r[k] = v
            end
        end

        return r
    end

    return deepcopy(proxy)
    
end

return m
