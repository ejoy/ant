local lfs = require "filesystem.local"
local sha1 = require "editor.hash".sha1
local serialize = import_package "ant.serialize"
local vfs = require "vfs"
local shader = require "editor.material.shader"

local function writefile(filename, data)
    local f = assert(lfs.open(filename, "wb"))
    f:write(data)
    f:close()
end

local config = {
    glb      = {setting={},arguments=""},
    model    = {setting={},arguments=""},
    texture  = {setting={},arguments=""},
    material = {setting={},arguments=""},
    png      = {setting={},arguments=""},
}

local ResourceCompiler <const> = {
    model   = "editor.model.convert",
    glb     = "editor.model.glb",
    texture = "editor.texture.convert",
    material = "editor.material.convert",
    png     = "editor.texture.png",
}

local function parse(arguments)
    local setting = {}
    arguments:gsub("([^=&]*)=([^=&]*)", function(k ,v)
        setting[k] = v
    end)
    return setting
end

local function init()
    shader.init()
end

local function set(ext, arguments)
    local cfg = config[ext]
    if not cfg then
        error("invalid type: " .. ext)
    end
    local hash = sha1(arguments):sub(1,7)
    cfg.setting = parse(arguments)
    cfg.binpath = lfs.path(vfs.repopath()) / ".build" / ext / hash
    cfg.compiler = require(assert(ResourceCompiler[ext]))
    lfs.create_directories(cfg.binpath)
    writefile(cfg.binpath / ".setting", serialize.stringify(cfg.setting))
end

local function get(ext)
    return assert(config[ext])
end

return {
    init = init,
    set = set,
    get = get,
}
