local thread = require "thread"
local math3d = require "math3d"
local fs = require "filesystem"
local lfs = require "filesystem.local"
local builtin = require "builtin"

local pack = thread.pack
local unpack = thread.unpack

local function write_file(filename, data)
    local f = lfs.open(fs.path(filename):localpath(), "wb")
    f:write(data)
    f:close()
end

local function save_meshbin(world, eid, filename)
    local e = world[eid]
    assert(e.mesh._data == nil)
    if e.mesh.bounding then
        local t = math3d.totable(e.mesh.bounding.aabb)
        e.mesh.bounding.aabb = {
            {t[1],t[2],t[3]},
            {t[4],t[5],t[6]},
        }
    end
    write_file(filename, pack(e.mesh))
    e.mesh = world.component "mesh" (filename)
end

local function save_prefab(world, eid, filename)
    write_file(filename, world:serialize {eid})
end

return {
    save_meshbin = save_meshbin,
    save_prefab = save_prefab,

    parse = require "parse",
    stringify = require "stringify",
    patch = require "patch",

    pack = pack,
    unpack = unpack,

    path = builtin.path
}
