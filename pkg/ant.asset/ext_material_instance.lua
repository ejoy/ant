local serialize = import_package "ant.serialize"
local fs        = require "filesystem"
local fastio    = require "fastio"
local assetmgr  = import_package "ant.asset"

local function loader (filename)
    -- .material_instance
    local material_instance = serialize.parse(filename, fastio.readall(fs.path(filename):localpath():string(), filename))
    -- .material
    local m = assetmgr.resource(material_instance.material)
    for k, p in pairs(material_instance.properties) do
        m[k] = p
    end

    return m
end

local function unloader()
    -- temp memory will be released in render_system
end

return {
    loader = loader,
    unloader = unloader,
}