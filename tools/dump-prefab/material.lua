local serialize = import_package "ant.serialize"
local datalist = require "datalist"
local fs = require "filesystem"
local function readfile(filename)
    local f<close> = fs.open(filename)
    return f:read "a"
end

local sha1 = require "sha1"

local function load_(filename)
    local c = datalist.parse(readfile(filename))
    local properties = c.properties
    local res = {
        diffuse = properties.s_basecolor.texture,
        normal = properties.s_normal.texture,
        metallic_roughness = properties.s_metallic_roughness.texture,
    }

    local bin = serialize.pack(res)
    return {
        material = "material-" .. sha1(bin),
        value = res,
    }
end

local cache = {}
local function load(filename)
    local r = cache[filename]
    if r then
        return r
    end
    r = load_(filename)
    cache[filename] = r
    return r
end

return {
    load = load
}