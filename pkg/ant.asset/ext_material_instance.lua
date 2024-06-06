local serialize = import_package "ant.serialize"
local assetmgr  = import_package "ant.asset"

local function loader (filename)
    -- .material_instance
    local material_instance = serialize.load(filename)
    -- .material
    local m = assetmgr.resource(material_instance.material)
    for k, p in pairs(material_instance.properties) do
        m[k] = p
    end

    return m
end

-- temp memory will be released in render_system, no unloader

return {
    loader = loader,
}