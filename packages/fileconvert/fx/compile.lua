local toolset 	= require "fx.toolset"
local lfs 		= require "filesystem.local"
local fs		= require "filesystem"
local util 		= require "util"
local vfs 		= require "vfs"

local engine_shader_srcpath = lfs.current_path() / "packages/resources/shaders"
local function check_compile_shader(plat, srcfilepath, outfilepath, shadertype, macros)	
	lfs.create_directories(outfilepath:parent_path())
	return toolset.compile(srcfilepath, outfilepath, shadertype, {
		includes = {engine_shader_srcpath},
		platform = plat,
		macros = macros,
	})
end

local shadertypes = {
	NOOP       = "d3d9",
	DIRECT3D9  = "d3d9",
	DIRECT3D11 = "d3d11",
	DIRECT3D12 = "d3d11",
	GNM        = "pssl",
	METAL      = "metal",
	OPENGL     = "glsl",
	OPENGLES   = "essl",
	VULKAN     = "spirv",
}

local function rawtable(filepath)
	local env = {}
	local r = assert(lfs.loadfile(filepath, "t", env))
	r()
	return env
end

local valid_shader_stage = {
	"vs", "fs", "cs"
}

local function embed_shader_bin(bins)
	local t = {}
	for k, b in pairs(bins)do
		assert(#k == 2)
		t[#t+1] = k .. string.pack("<I4", #b)
		t[#t+1] = b
	end
	return t
end

return function (identity, srcfilepath, outfilepath)
	local plat, renderer = util.identify_info(identity)
	local shadertype = shadertypes[renderer:upper()]
	assert(plat)
	assert(shadertype)

	local fxcontent = rawtable(srcfilepath)
	local shader = assert(fxcontent.shader)
	local marcros = shader.macros

	local messages = {}
	local all_depends = {}
	local build_success = true

	local binarys = {}
	
	for _, stagename in ipairs(valid_shader_stage) do
		local stage_file = shader[stagename]
		if stage_file then
			local shader_srcpath = fs.path(stage_file):localpath()
			local success, msg, depends = check_compile_shader(plat, shader_srcpath, outfilepath, shadertype, marcros)
			build_success = build_success and success
			messages[#messages+1] = msg

			if success then
				for _, d in ipairs(depends) do
					if all_depends[d:string()] == nil then
						all_depends[d:string()] = d
					end
				end
				binarys[stagename] = util.fetch_file_content(outfilepath)
			end
		end
	end

	if build_success then
		util.embed_file(outfilepath, fxcontent, embed_shader_bin(binarys))
	end

	local function depend_files()
		local t = {}
		for k in pairs(all_depends) do
			t[#t+1] = k
		end
		table.sort(t)
		local tt = {}
		for _, n in ipairs(t) do
			tt[#tt+1] = all_depends[n]
		end
		return tt
	end
	return build_success, table.concat(messages, "\n"), depend_files()
end
