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
        init = function() end,
        compile = compile,
        clean = function() end,
        compile_fx = fx.loader,
        read_file = read_file,
    }
end

local compile = require "compile"

--TODO
local function init()
    local os = require "platform".OS
    local renderer = import_package "ant.render".hwi.get_caps().rendererType
    local identity = (os.."_"..renderer):lower()
    fx.init(identity)
    compile.register("glb", identity)
    compile.register("texture", identity)
end

local function read_file(filename)
    local f = assert(lfs.open(compile.compile(filename), "rb"))
    local c = f:read "a"
    f:close()
    return c
end

return {
    init = init,
    compile = compile.compile,
    clean = compile.clean,
    compile_fx = fx.loader,
    read_file = read_file,
}
