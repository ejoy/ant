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

--TODO
local function init()
    local renderpkg = import_package "ant.render"
    local hw = renderpkg.hwi
    compile.register("fx", "win", {identity=hw.identity(), setting=load_fx_setting()})
    compile.register("mesh", "win", {identity=hw.identity(),})
    compile.register("texture", "win", {identity=hw.identity(),})
end

return {
    init = init,
    register = compile.register,
    compile = compile.compile,
    ------
    util = require "util",
	compile_fx = require "fx.compile",
	shader_toolset = require "fx.toolset",
}
