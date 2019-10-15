local toolset 	= require "fx.toolset"
local lfs 		= require "filesystem.local"
local util 		= require "util"
local vfs 		= require "vfs"

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

return function (identity, srcfilepath, outfilepath)
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
			local shader_srcpath = lfs.path(vfs.realpath(stage_file))
			local success, msg, depends = check_compile_shader(identity, shader_srcpath, outfilepath, marcros)
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
