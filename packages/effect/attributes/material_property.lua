local inputparam = ...
local world, attrib = inputparam[1], inputparam[2]

local imaterial = world:interface "ant.asset|imaterial"
local assetmgr = import_package "ant.asset"
local function init_properties(properties)
    for _, v in pairs(properties) do
        if v.stage then
            v.texture = assetmgr.resource(v.texture)
        end
    end
    return properties
end

local attribinst = setmetatable({}, {__index=attrib})

function attribinst:init(e)
    local data = self.data
    if data.method == "change_property" then
        if data.properties == nil then
            log.warn("no properties define")
            return
        end

        local p = e._rendercache.properties
        for k, v in pairs(init_properties(data.properties)) do
            if p[k] then
                imaterial.set_property_directly(p, k, v)
            end
        end
    else
        error(("not support method:%d"):format(data.method))
    end
end

return attribinst