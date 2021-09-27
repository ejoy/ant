local lfs = require "filesystem.local"
local cm = require "compile"
local fx = require "load_fx"
local config = require "config"
local ltask = require "ltask"

if not __ANT_RUNTIME__ then
    require "editor.compile"
end

local function read_file(filename)
    local f = assert(lfs.open(cm.compile(filename), "rb"))
    local c = f:read "a"
    f:close()
    return c
end

local function init()
    local v = import_package "ant.hwi".get_identity()
    config.set_setting("glb", {identity=v})
    config.set_setting("sc", {identity=v})
    config.set_setting("texture", {identity=v})
    config.set_setting("png", {identity=v})
end

return {
    init = init,
    read_file = read_file,
    load_fx = fx.load,
    compile = cm.compile,
    compile_path = cm.compile_path,
    compile_dir = cm.compile_dir,
}
