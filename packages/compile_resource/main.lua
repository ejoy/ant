local fx = require "fx.load"
local lfs = require "filesystem.local"

local cm
if __ANT_RUNTIME__ then
    local fs = require "filesystem"
    cm = {}
    function cm.set_identity()
    end
    function cm.compile_file(filename)
        return filename
    end
    function cm.compile_path(pathstring)
        return fs.path(pathstring:gsub("|", "/")):localpath()
    end
    function fx.set_identity()
    end
    function fx.compile()
    end
else
    cm = require "compile"
end

local function set_identity(v)
    fx.set_identity(v)
    cm.set_identity("glb", v)
    cm.set_identity("texture", v)
    cm.set_identity("png", v)
end

local function read_file(filename)
    local f = assert(lfs.open(cm.compile_path(filename), "rb"))
    local c = f:read "a"
    f:close()
    return c
end

local function compile(filename)
    return cm.compile_file(cm.compile_path(filename))
end

return {
    set_identity = set_identity,
    compile = compile,
    read_file = read_file,
    compile_fx = fx.compile,
    load_fx = fx.loader,
}
