local assetmgr = import_package "ant.asset"
local function init_properties(properties)
    for _, v in pairs(properties) do
        if v.stage then
            v.texture = assetmgr.resource(v.texture)
        end
    end
end

return {
    init = function (world, emittereid, attrib)
        local data = attrib.data
        if data.method == "change_property" then
            local properties = data.properties
            local imaterial = world:interface "ant.asset|imaterial"

            init_properties(properties)
            for k, v in pairs(properties) do
                if imaterial.has_property(emittereid, k) then
                    imaterial.set_property(emittereid, k, v)
                end
            end
        else
            error(("not support method:%d"):format(data.method))
        end
    end
}