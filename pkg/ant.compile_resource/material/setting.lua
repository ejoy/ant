local datalist = require "datalist"
local vfs_fastio = require "vfs_fastio"

local function default_fx_setting(setting)
    if not setting.default_fx_setting then
        setting.default_fx_setting = datalist.parse(vfs_fastio.readall_f(setting.vfs, "/pkg/ant.resources/settings/default.ant"))
    end
    return setting.default_fx_setting
end

local function add_default(setting, input)
    local output = {}
    for k, v in pairs(input) do
        output[k] = v
    end
    local def = default_fx_setting(setting)
    for k, v in pairs(def) do
        if not output[k] then
            output[k] = v
        end
    end
    return output
end

local function del_default(setting, input)
    local def = default_fx_setting(setting)
    local output = {}
    for k, v in pairs(input) do
        if def[k] ~= v then
            output[k] = v
        end
    end
    return output
end

return {
    adddef = add_default,
    deldef = del_default,
}
