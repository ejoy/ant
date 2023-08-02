local serialize = import_package "ant.serialize"
local fs 	    = require "filesystem"
local assetmgr 		= import_package "ant.asset"

local function readall(filename)
    local f <close> = assert(fs.open(fs.path(filename), "rb"))
    return f:read "a"
end

local function loader (filename)
    -- .material_instance
    local material_instance = serialize.parse(filename, readall(filename))
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