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

local function set(ext, arguments)
    local cfg = config[ext]
    if not cfg then
        error("invalid type: " .. ext)
    end
    cfg.arguments = arguments
    cfg.setting = parse(arguments)
    assert(not __ANT_RUNTIME__)
    if not __ANT_RUNTIME__ then
        local lfs   = require "filesystem.local"
        local sha1  = require "hash".sha1
        local serialize = import_package "ant.serialize".stringify
        local vfs = require "vfs"
        local hash = sha1(cfg.arguments):sub(1,7)
        local function writefile(filename, data)
            local f = assert(lfs.open(filename, "wb"))
            f:write(data)
            f:close()
        end
        cfg.binpath = lfs.path(vfs.repopath()) / ".build" / ext / hash
        cfg.compiler = assert(ResourceCompiler[ext])
        lfs.create_directories(cfg.binpath)
        writefile(cfg.binpath / ".setting", serialize(cfg.setting))
    end
end

local function get(ext)
    return config[ext]
end

return {
    set = set,
    get = get,
}
