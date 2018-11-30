local fs = require "lfs"
local fspath = require "filesystem.path"
local util = require "filesystem.util"
local subprocess = require "subprocess"
local config = require "common.config"
local rawtable = require "common.rawtable"

local PATH = "ant"

local toolset = {}

local cwd = fs.currentdir()

if cwd == nil or cwd == "" then
	error("empty cwd!")
end

local default_toolset

if config.platform() == "OSX" then
	default_toolset = {
		lua = cwd .. "/clibs/lua/lua",
		shaderc = cwd .. "/3rd/bgfx/.build/osx64_clang/bin/shadercRelease",
		shaderinc = cwd .. "/3rd/bgfx/src",
	}
else
	default_toolset = {
		lua = cwd .. "/clibs/lua/lua.exe",
		shaderc = cwd .. "/3rd/bgfx/.build/win64_mingw-gcc/bin/shadercRelease.exe",
		shaderinc = cwd .. "/3rd/bgfx/src",
	}
end

function toolset.load_config()
	return toolset.path
end

local function home_path()
	local home = util.personaldir()
	local home_path = home .. "/" .. PATH
	local attrib = fs.attributes(home_path, "mode")
	print(attrib)
	if not attrib then
		assert(fs.mkdir(home_path))
	else
		assert(attrib == "directory")
	end
	return home_path
end

function toolset.save_config(path)
	local home_path = home_path()
	local f = io.open(home_path .. "/toolset.lua", "wb")
	for k,v in pairs(path or toolset.path) do
		f:write(string.format("%s = %q\n", k,v))
	end
	f:close()
end

local stage_types = {
	f = "fragment",
	v = "vertex",
	c = "compute",
}

local shader_options = {
	d3d9_v = "-p vs_3_0 -O 3",
	d3d9_f = "-p ps_3_0 -O 3",	
	d3d11_v = "-p vs_4_0 -O 3",
	d3d11_f = "-p ps_4_0 -O 3",
	d3d11_c = "-p cs_5_0 -O 1",	
	glsl_v ="-p 120",
	glsl_f ="-p 120",
	glsl_c ="-p 430",	
	metal_v = "",
	metal_f = "",
	metal_c = "",
	vulkan_v = "",
	vulkan_f = "",	
}

function toolset.compile(filename, paths, shadertype, platform, stagetype, shader_opt)
	paths = paths or toolset.path

	if filename then
		local dest = paths.dest or filename:gsub("(%w+).sc", "%1") .. ".bin"

		local shaderc = paths.shaderc
		if shaderc and not util.exist(shaderc)then
			error(string.format("bgfx shaderc path is privided, but file is not exist, path is : %s. \
								you can locate to ant folder, and run : bin/iup.exe tools/config.lua, to set the right path", shaderc))
		end

		local tbl = {
			shaderc = paths.shaderc,
			src = filename,
			dest = dest,
			inc = {},
			stype = nil,
			sopt = nil,
			splat = nil,
		}
		
		local includes = paths.includes
		if includes then
			local function add_inc(p)
				table.insert(tbl.inc, "-i")
				table.insert(tbl.inc, p)
			end
			for _, p in ipairs(includes) do
				if not util.exist(p) then
					error(string.format("include path : %s, but not exist!", p))
				end
				
				add_inc(p)
			end
			if paths.not_include_examples_common == nil then				
				if paths.shaderinc and (not util.exist(paths.shaderinc)) then
					error(string.format("bgfx shader include path is needed, \
										but path is not exist! path have been set : %s", paths.shaderinc))
				end

				local incexamplepath = fspath.join(paths.shaderinc, "../examples/common")
				if not util.exist(incexamplepath) then
					error(string.format("example is needed, but not exist, path is : %s", incexamplepath))
				end
				
				add_inc(incexamplepath)
			end
		end

		stagetype = stagetype or filename:match "[/\\]([fvc])s_[^/\\]+.sc$"
		shader_opt = shader_opt or assert(shader_options[shadertype .. "_" .. stagetype], shadertype .. "_" .. stagetype)

		tbl.stype = assert(stage_types[stagetype], stagetype)
		tbl.splat = assert(platform)
		tbl.sopt = assert(shader_opt)

		local prog, stdout, stderr = subprocess.spawn {
			tbl.shaderc,
			"--platform", tbl.splat,
			"--type", tbl.stype,
			tbl.sopt,
			"-f", tbl.src,
			"-o", tbl.dest,
			tbl.inc,
			stdout = true,
			stderr = true,
			hideWindow = true,
		}

		if not prog then
			return false, "Create shaderc process failed."
		else
			local function read_std_info(std)
				local ret = std:read "a"
				std:close()
				local success, err = true, ""
				if ret and ret ~= "" then
					success = ret:find("error", 1, true) == nil
					if not success then

						local function cmd_desc(tbl)
							local inc = ''
							for _, i in ipairs(tbl.inc) do
								inc = inc .. '\t' .. i
							end

							return string.format(
								"shaderc:%s\n\
								platform:%s\n\
								type:%s\n\
								option:%s\n\
								source:%s\n\
								output:%s\n\
								includes:%s\n", tbl.shaderc, tbl.splat, tbl.stype, tbl.soptn, tbl.src, tbl.dest, inc)
						end
						err = err .. cmd_desc(tbl) .. "\n" .. ret
					end
				end
	
				return success, err
			end

			local success, err = true, ""
			for _, std in ipairs {stdout, stderr} do
				local s, e = read_std_info(std)
				success = success and s
				err = err .. "\n" .. e
			end
			return success, err
		end
	end
end

local function load_config()
	local home = util.personaldir()
	local toolset_path = string.format("%s/%s/toolset.lua", home, PATH)
	
	local ret = {}	
	if util.exist(toolset_path) then		
		ret = rawtable(toolset_path, util.read_from_file)
	end
	return ret
end

toolset.path = setmetatable(load_config(), { __index = default_toolset })
toolset.homedir = home_path()

return toolset
