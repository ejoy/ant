local fs = require "filesystem"
local datalist = require "datalist"

local function read_default_setting_from_file()
    local f<close> = fs.open (fs.path "/pkg/ant.resources/settings/default.setting")
    return f:read "a"
end

local defaultSetting = datalist.parse(read_default_setting_from_file())

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
