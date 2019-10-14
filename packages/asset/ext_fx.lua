local assetmgr  = require "asset"
local bgfx      = require "bgfx"
local shadermgr = require "shader_mgr"
local assetutil = require "util"

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

local function fetch_shader_binarys(binary)
    local pos = 1
    local shaders = {}

    while pos < #binary do
        local stagename, stagelen = string.unpack("<c2I4", binary, pos)
        pos = pos + 2 + 4

        shaders[stagename] = binary:sub(pos, pos-1+stagelen)
        pos = pos + stagelen
    end

    return shaders
end

return {
    loader = function (fxpath)
        local content, binary = assetutil.parse_embed_file(fxpath)
        local shaderbins = fetch_shader_binarys(assert(binary))
        local shader = content.shader

        if shader.cs == nil then
            local vs = load_shader(assert(shaderbins.vs), shader.vs)
            local fs = load_shader(assert(shaderbins.fs), shader.fs)

            shader.prog, shader.uniforms = shadermgr.create_render_program(vs, fs)
        else
            local cs = load_shader(shaderbins.cs, shader.cs)
            shader.prog, shader.uniforms = shadermgr.create_compute_program(cs)
            shader.csbin = nil
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