local lfs = require "filesystem.local"
local cm = require "compile"
local fx = require "load_fx"
local config = require "config"

local function set_identity(v)
    config.set_setting("glb", {})
    config.set_setting("sc", {identity=v})
    config.set_setting("texture", {identity=v})
    config.set_setting("png", {identity=v})
end

local function read_file(filename)
    local f = assert(lfs.open(cm.compile(filename), "rb"))
    local c = f:read "a"
    f:close()
    return c
end

return {
    set_identity = set_identity,
    set_setting = config.set_setting,
    read_file = read_file,
    load_fx = fx.load,
    compile = cm.compile,
    compile_url = cm.compile_url,
}
