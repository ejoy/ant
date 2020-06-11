local compile = require "compile"
local compile_fx = require "fx.compile"
local lfs = require "filesystem.local"

--TODO
local function init()
    local os = require "platform".OS
    local renderer = import_package "ant.render".hwi.get_caps().rendererType
    local identity = (os.."_"..renderer):lower()
    compile_fx.register(identity)
    compile.register("glb")
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
    register = compile.register,
    compile = compile.compile,
    compile_fx = compile_fx.loader,
    clean = compile.clean,
    read_file = read_file,
}
