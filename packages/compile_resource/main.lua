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
    return r
end

--TODO
local function init()
    local render = import_package "ant.render"
    local os = require "platform".OS:lower()
    local renderer = render.hwi.get_caps().rendererType:upper()
    compile.register("fx",      "win", {
        os = os,
        renderer = renderer,
        setting = load_fx_setting()
    })
    compile.register("glb",     "win", {
    })
    compile.register("texture", "win", {
        os = os,
        renderer = renderer,
    })
end

return {
    init = init,
    register = compile.register,
    compile = compile.compile,
    read_file = require "utility".read_file,
}
