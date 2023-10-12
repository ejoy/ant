local lfs = require "bee.filesystem"
local sha1 = require "sha1"
local serialize = import_package "ant.serialize"
local vfs = require "vfs"

local function writefile(filename, data)
    local f <close> = assert(io.open(filename:string(), "wb"))
    f:write(data)
end

local config = {
    glb = {
        compiler = require "model.glb",
    },
    texture = {
        compiler = require "texture.convert",
    },
    material = {
        compiler = require "material.convert",
    },
}

local function set(setting)
    local setting_str = serialize.stringify(setting)
    local hash = sha1(setting_str):sub(1,7)
    local binpath = lfs.path(vfs.repopath()) / ".build" / (setting.os.."_"..hash)
    lfs.create_directories(binpath)
    writefile(binpath / ".setting", setting_str)
    for ext, cfg in pairs(config) do
        cfg.setting = setting
        cfg.binpath = binpath / ext
        lfs.create_directory(cfg.binpath)
    end
end

local function get(ext)
    return assert(config[ext])
end

return {
    set = set,
    get = get,
}
