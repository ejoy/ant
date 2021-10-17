local fs = require "filesystem"
local setting = import_package "ant.settings".setting
local datalist = require "datalist"

local function read_default_setting_from_file()
    local f = fs.open (fs.path "/pkg/ant.resources/settings/default.setting")
    local c = f:read "a"
    f:close()
    return c
end

local defaultSetting = datalist.parse(read_default_setting_from_file())
defaultSetting.depth_type = setting:get 'graphic/shadow/type'
defaultSetting.bloom      = setting:get 'graphic/postprocess/bloom/enable' and "on" or "off"

local function add_default(input)
    local output = {}
    for k, v in pairs(input) do
        output[k] = v
    end
    for k, v in pairs(defaultSetting) do
        if not output[k] then
            output[k] = v
        end
    end
    return output
end

local function del_default(input)
    local output = {}
    for k, v in pairs(input) do
        if defaultSetting[k] ~= v then
            output[k] = v
        end
    end
    return output
end

return {
    adddef = add_default,
    deldef = del_default,
}
