local toolset 	= require "fx.toolset"
local lfs 		= require "filesystem.local"
local fs		= require "filesystem"
local util 		= require "util"

local assetpkg  = import_package "ant.asset"
local assetutil = assetpkg.util

local engine_shader_srcpath = lfs.current_path() / "packages/resources/shaders"
local function check_compile_shader(identity, srcfilepath, outfilepath, macros)
	lfs.create_directories(outfilepath:parent_path())
	return toolset.compile {
		identity = identity,
		srcfile = srcfilepath,
		outfile = outfilepath,
		includes = {engine_shader_srcpath},
		macros = macros,
	}
end

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

local function need_linear_shadow(identity)
	local plat, platinfo, renderer = util.identify_info(identity)
	if plat == "ios" then
		local a_series = platinfo:match "apple a(%d)"
		if a_series then
			return tonumber(a_series) <= 8
		end
	end
end

local function read_linkconfig(path, identity)
	local os = util.identify_info(identity)
	local settings = import_package "ant.settings".create(path, "r")
	settings:use(os)
	if settings:get 'graphic/shadow/type' ~= "linear" and need_linear_shadow(identity) then
		settings:set('_'..os..'/graphic/shadow/type', 'linear')
	end
	return settings:data()
end

local function add_macros_from_surface_setting(identity, mysetting, surfacetype, macros)
	surfacetype = assetutil.load_surface_type(surfacetype)
	macros = macros or {}

	if surfacetype.lighting == "on" then
		macros[#macros+1] = "ENABLE_LIGHTING"
	end

	local shadow = surfacetype.shadow
	if shadow.receive == "on" then
		macros[#macros+1] = "ENABLE_SHADOW"
	end

	if mysetting.graphic.shadow.type == "linear" then
		macros[#macros+1] = "SM_LINEAR"
	end

	if mysetting.graphic.postprocess.bloom.enable then
		macros[#macros+1] = "BLOOM_ENABLE"
	end

	macros[#macros+1] = "ENABLE_SRGB_TEXTURE"
	macros[#macros+1] = "ENABLE_FB_SRGB"
	
	return macros
end

local function depend_files(files)
	local t = {}
	for k in pairs(files) do
		t[#t+1] = k
	end
	table.sort(t)
	local tt = {}
	for _, n in ipairs(t) do
		tt[#tt+1] = files[n]
	end
	return tt
end

return function (identity, srcfilepath, outfilepath, localpath)
	local fxcontent = rawtable(srcfilepath)

	local mysetting	= read_linkconfig(localpath("settings"), identity)
	local marcros 	= add_macros_from_surface_setting(identity, mysetting, fxcontent.surface_type, fxcontent.macros)

	local messages = {}
	local all_depends = {}
	local build_success = true

	local binarys = {}
	
	local shader 	= assert(fxcontent.shader)
	for _, stagename in ipairs(valid_shader_stage) do
		local stage_file = shader[stagename]
		if stage_file then
			local shader_srcpath = localpath(stage_file)
			all_depends[shader_srcpath:string()] = shader_srcpath
			local success, msg, depends = check_compile_shader(identity, shader_srcpath, outfilepath, marcros)
			build_success = build_success and success
			messages[#messages+1] = msg

			if success then
				for _, d in ipairs(depends) do
					all_depends[d:string()] = d
				end
				binarys[stagename] = util.fetch_file_content(outfilepath)
			end
		end
	end

	if build_success then
		util.embed_file(outfilepath, fxcontent, embed_shader_bin(binarys))
	end
	return build_success, table.concat(messages, "\n"), depend_files(all_depends)
end
