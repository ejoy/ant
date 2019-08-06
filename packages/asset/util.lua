local util = {}; util.__index = util

local shader_mgr = require "shader_mgr"
local assetmgr = require "asset"
local fs = require "filesystem"

local function check_add_shader_file_extension(filepath)
    return fs.path(filepath):replace_extension ".sc"
end

function util.load_shader_program(shader)
    if shader.cs == nil then
        local vs = assetmgr.load(check_add_shader_file_extension(shader.vs))
        local fs = assetmgr.load(check_add_shader_file_extension(shader.fs))
        
        shader.prog, shader.uniforms = shader_mgr.create_render_program(vs, fs)
    else
        local cs = assetmgr.load(check_add_shader_file_extension(shader.cs))
        shader.prog, shader.uniforms = shader_mgr.create_compute_program(cs)
    end
    return shader
end

function util.unload_shader_program(shader)
    shader_mgr.destroy_program()

    for _, name in ipairs {"vs", "fs", "cs"} do
		local shaderpath = check_add_shader_file_extension(shader[name])
		if shaderpath then
            assert(type(shaderpath) == "userdata")
            
			local res = assetmgr.get_resource(shaderpath)
			assetmgr.unload(res, shaderpath)
			shader[name] = nil
		end
	end
end

function util.load_material_properties(properties)
	if properties then
		local textures = properties.textures
		if textures then
			for _, tex in pairs(textures) do
				assetmgr.load(tex.ref_path)
			end
		end
		return properties
	end
end

function util.unload_material_properties(properties)
    if properties then
        local textures = properties.textures
        if textures then
            for _, tex in pairs(textures) do
                assetmgr.unload(tex.ref_path)
            end
        end
    end
end

return util