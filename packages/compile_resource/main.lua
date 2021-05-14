local fx = require "fx.load"
local lfs = require "filesystem.local"

local cm = require "compile"

local function set_identity(v)
    fx.set_identity(v)
    cm.set_identity("glb", v)
    cm.set_identity("texture", v)
    cm.set_identity("png", v)
end

local function read_file(filename)
    local f = assert(lfs.open(cm.compile(filename), "rb"))
    local c = f:read "a"
    f:close()
    return c
end

local function compile(filename)
    return cm.compile(filename)
end

return {
    set_identity = set_identity,
    compile = compile,
    read_file = read_file,
    load_fx = fx.load,
    compile_fx = fx.compile,
}
