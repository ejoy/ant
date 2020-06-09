local compile = require "compile"
local compile_fx = require "compile_fx"
local lfs = require "filesystem.local"

local function load_fx_setting()
    local renderpkg = import_package "ant.render"
    local setting = renderpkg.setting.get()

    local function get_setting(path, r)
        local s = setting
        local paths = {}
        for m in path:gmatch "[^/]+" do
            paths[#paths+1] = m
        end
        local last = r
        for i=1, #paths-1 do
            local p = paths[i]
            local c = last[p]
            if c == nil then
                c = {}
                last[p] = c
            end

            last = c
            s = s[p]
        end
        local p = paths[#paths]
        last[p] = s[p]
        return r
    end

    local r = {}
    get_setting("graphic/shadow/type", r)
    get_setting("graphic/postprocess/bloom/enable", r)
    return r
end

--TODO
local function init()
    local render = import_package "ant.render"
    local os = require "platform".OS:lower()
    local renderer = render.hwi.get_caps().rendererType:lower()
    compile_fx.register("win", {
        os = os,
        renderer = renderer:upper(),
        setting = load_fx_setting()
    })
    compile.register("glb")
    compile.register("texture", os.."_"..renderer)
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
    compile_fx = compile_fx.compile,
    clean = compile.clean,
    read_file = read_file,
}
