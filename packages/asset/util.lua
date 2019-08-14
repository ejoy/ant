local util = {}; util.__index = util

local shader_mgr = require "shader_mgr"
local assetmgr = require "asset"
local fs = require "filesystem"

function util.create_shader_program_from_file(shader)
    local shader_loader = require "ext_sc".loader
    if shader.cs == nil then
        local vs = shader_loader(shader.vs)
        local fs = shader_loader(shader.fs)
        
        shader.prog, shader.uniforms = shader_mgr.create_render_program(vs, fs)
    else
        local cs = assetmgr.load(shader.cs)
        shader.prog, shader.uniforms = shader_mgr.create_compute_program(cs)
    end
    return shader
end

function util.load_shader_program(shader)
    if shader.cs == nil then
        local vs = assetmgr.load(shader.vs)
        local fs = assetmgr.load(shader.fs)
        
        shader.prog, shader.uniforms = shader_mgr.create_render_program(vs, fs)
    else
        local cs = assetmgr.load(shader.cs)
        shader.prog, shader.uniforms = shader_mgr.create_compute_program(cs)
    end
    return shader
end

function util.unload_shader_program(shader)
    shader_mgr.destroy_program(shader)

    for _, name in ipairs {"vs", "fs", "cs"} do
		local shaderpath = shader[name]
		if shaderpath then
            assert(type(shaderpath) ~= "string")
            assetmgr.unload(shaderpath)
			shader[name] = nil
		end
	end
end

local function mnext(tbl, index)
    if tbl then
        local k, v
        while true do
            k, v = next(tbl, index)
            local tt = type(k)
            if tt == "string" or tt == "nil" then
                break
            end
            index = k
        end

        return k, v
    end
end

function util.mpairs(t)
    return mnext, t, nil
end

function util.each_texture(properties)
    if properties then
        local textures = properties.textures
        if textures then
            return util.mpairs(textures)
        end
    end
    return mnext, nil, nil
end

function util.load_material_textures(properties)
    for _, tex in util.each_texture(properties) do
        assetmgr.load(tex.ref_path)
    end

	return properties
end

function util.unload_material_textures(properties)
    for _, tex in util.each_texture(properties) do
        assetmgr.unload(tex.ref_path)
    end
end

function util.load_material_properties(properties)
    return util.load_material_textures(properties)
end

function util.unload_material_properties(properties)
    util.unload_material_textures(properties)
end

return util