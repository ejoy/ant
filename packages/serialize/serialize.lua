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

local function save_prefab(world, eid, filename)
    write_file(filename, world:serialize {eid})
end

return {
    save_prefab = save_prefab,

    parse = require "parse",
    stringify = require "stringify",
    patch = require "patch",

    pack = pack,
    unpack = unpack,

    path = builtin.path
}
