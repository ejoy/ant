local fx = require "fx.load"
local lfs = require "filesystem.local"

if __ANT_RUNTIME__ then
    local fs = require "filesystem"
    local function compile(pathstring)
        return fs.path(pathstring:gsub("|", "/")):localpath()
    end
    local function read_file(filename)
        local f = assert(lfs.open(compile(filename), "rb"))
        local c = f:read "a"
        f:close()
        return c
    end
    return {
        set_identity = function() end,
        compile = compile,
        load_fx = fx.loader,
        read_file = read_file,
    }
end

local compile = require "compile"

local function set_identity(v)
    fx.set_identity(v)
    compile.set_identity("glb", v)
    compile.set_identity("texture", v)
    compile.set_identity("png", v)
end

local function read_file(filename)
    local f = assert(lfs.open(compile.compile(filename), "rb"))
    local c = f:read "a"
    f:close()
    return c
end

return {
    set_identity = set_identity,
    compile = compile.compile,
    compile_fx = fx.compile,
    load_fx = fx.loader,
    read_file = read_file,
}
