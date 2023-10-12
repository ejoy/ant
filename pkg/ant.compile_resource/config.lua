local lfs = require "bee.filesystem"
local sha1 = require "sha1"
local serialize = import_package "ant.serialize"
local vfs = require "vfs"

local function writefile(filename, data)
    local f <close> = assert(io.open(filename:string(), "wb"))
    f:write(data)
end

local config = {}

local ResourceCompiler <const> = {
    glb     = "model.glb",
    texture = "texture.convert",
    material = "material.convert",
}

local function parse(arguments)
    local setting = {}
    arguments:gsub("([^=&]*)=([^=&]*)", function(k ,v)
        setting[k] = v
    end)
    return setting
end

local function set(ext, arguments)
    if not ResourceCompiler[ext] then
        error("invalid type: " .. ext)
    end
    local cfg = {}
    local hash = sha1(arguments):sub(1,7)
    cfg.setting = parse(arguments)
    cfg.binpath = lfs.path(vfs.repopath()) / ".build" / ext / hash
    cfg.compiler = require(assert(ResourceCompiler[ext]))
    lfs.create_directories(cfg.binpath)
    writefile(cfg.binpath / ".setting", serialize.stringify(cfg.setting))
    config[ext] = cfg
end

local function get(ext)
    return assert(config[ext])
end

return {
    set = set,
    get = get,
}
