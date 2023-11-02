local datalist = require "datalist"
local fastio = import_package "ant.serialize".fastio

local defaultSetting = datalist.parse(fastio.readall "/pkg/ant.resources/settings/default.settings")

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
