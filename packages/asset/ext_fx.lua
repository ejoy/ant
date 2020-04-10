local bgfx      = require "bgfx"
local shadermgr = require "shader_mgr"
local assetutil = import_package "ant.fileconvert".util

local function load_shader(shaderbin, filename)
    local h = bgfx.create_shader(shaderbin)
    bgfx.set_name(h, filename)
    return {
        handle = h,
        uniforms = bgfx.get_shader_uniforms(h),
    }
end

return {
    loader = function (fxpath)
        local config, shaderbins = assetutil.read_embed_file(fxpath)
        local shader = config.shader
        if shader.cs == nil then
            local vs = load_shader(assert(shaderbins.vs), shader.vs)
            local fs = load_shader(assert(shaderbins.fs), shader.fs)
            shader.prog, shader.uniforms = shadermgr.create_render_program(vs, fs)
        else
            local cs = load_shader(shaderbins.cs, shader.cs)
            shader.prog, shader.uniforms = shadermgr.create_compute_program(cs)
            shader.csbin = nil
        end
        return config, 0
    end,

    unloader = function (res)
        local shader = res.shader
        bgfx.destroy(shader.prog)
        res.shader = nil
        res.surface_type = nil
    end
}
