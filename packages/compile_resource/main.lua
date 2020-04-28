local compile = require "compile"

local function load_fx_setting()
    local renderpkg = import_package "ant.render"
    local setting = renderpkg.setting.get()

    return {
        graphic = {
            shadow = {
                type = setting.graphic.shadow.type,
            },
            postprocess = {
                bloom = {
                    enable = setting.graphic.postprocess.bloom.enable,
                }
            }
        }
    }
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
