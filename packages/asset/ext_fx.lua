local assetutil = require "util"
local assetmgr  = require "asset"
local fs        = require "filesystem"
local bgfx      = require "bgfx"
local shadermgr = require "shader_mgr"

local function def_surface_type()
	return {
		lighting = "on",			-- "on"/"off"
		transparency = "opaticy",	-- "opaticy"/"translucent"
		shadow	= {
			cast = "on",			-- "on"/"off"
			receive = "on",			-- "on"/"off"
		},
		subsurface = "off",			-- "on"/"off"? maybe has other setting
	}
end

local function load_surface_type(surfacetype)
	if surfacetype == nil then
		return def_surface_type()
	end

	for k, v in pairs(def_surface_type()) do
		if surfacetype[k] == nil then
			surfacetype[k] = v
		end
	end
	return surfacetype
end

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
        local content = assetmgr.load_depiction(fxpath)
        local shader = content.shader

        if shader.cs == nil then
            local vs = load_shader(shader.vsbin, shader.vs)
            local fs = load_shader(shader.fsbin, shader.fs)

            shader.prog, shader.uniforms = shadermgr.create_render_program(vs, fs)
        else
            local cs = assetmgr.load(shader.cs)
            shader.prog, shader.uniforms = shadermgr.create_compute_program(cs)
        end

        return {
            shader      = shader,
            surface_type= load_surface_type(content.surface_type),
        }
    end,

    unloader = function (res)
        assert(false, "not implement")
    end
}