local compile = require "compile"

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
    get_setting("animation/skinning/type", r)
    return r
end

local compiler = {
	fx		= require "fx.compile",
	mesh 	= require "mesh.convert",
	texture = require "texture.convert",
}

--TODO
local function init()
    local renderpkg = import_package "ant.render"
    local hw = renderpkg.hwi
    compile.register("fx", compiler.fx)
    compile.register("mesh", compiler.mesh)
    compile.register("texture", compiler.texture)

    compile.set_config("fx", "win", {identity=hw.identity(), setting=load_fx_setting()})
    compile.set_config("mesh", "win", {identity=hw.identity(),})
    compile.set_config("texture", "win", {identity=hw.identity(),})
end

return {
    init = init,
    register = compile.register,
    set_config = compile.set_config,
    compile = compile.compile,
    ------
    util = require "util",
	compiler = compiler,
	shader_toolset = require "fx.toolset",
}
