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
		shaderc = cwd .. "/3rd/bgfx/.build/win64_vs2017/bin/shadercDebug.exe",
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
	d3d9_v = "vs_3_0",
	d3d9_f = "ps_3_0",	
	d3d11_v = "vs_4_0",
	d3d11_f = "ps_4_0",
	d3d11_c = "cs_5_0",	
	glsl_v ="120",
	glsl_f ="120",
	glsl_c ="430",
	metal_v = "metal",
	metal_f = "metal",
	metal_c = "metal",
	vulkan_v = "spirv",
	vulkan_f = "spirv",	
}

function toolset.compile(filename, paths, shadertype, platform, stagetype, shader_opt, optimizelevel)
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

		local cmdline = {
			tbl.shaderc,
			"--platform", tbl.splat,
			"--type", tbl.stype,
			"-p", tbl.sopt,
			"-f", tbl.src,
			"-o", tbl.dest,			
			tbl.inc,
			stdout = true,
			stderr = true,
			hideWindow = true,
		}

		local function default_level(shadertype, stagetype)
			if shadertype:match("d3d") then
				return stagetype == "c" and 1 or 3
			end
		end

		local function add_optimizelevel(level, defaultlevel)			
			level = level or defaultlevel
			if level then
				table.insert(cmdline, "-O")
				table.insert(cmdline, tostring(level))
			end
		end

		add_optimizelevel(optimizelevel, default_level(shadertype, stagetype))

		local prog = subprocess.spawn(cmdline)

		-- local function to_cmdline()
		-- 	local s = ""
		-- 	for _, v in ipairs(cmdline) do
		-- 		if type(v) == "table" then
		-- 			for _, vv in ipairs(v) do
		-- 				s = s .. vv .. " "
		-- 			end
		-- 		else
		-- 			s = s .. v .. " "
		-- 		end				
		-- 	end

		-- 	return s
		-- end

		-- print(to_cmdline())

		if not prog then
			return false, "Create shaderc process failed."
		else
			local function read_std_info(std)
				local ret = ""
				while true do
					local num = subprocess.peek(std)
					if num == nil then
						break
					end

					if num ~= 0 then
						ret = ret .. std:read(num)						
					end					
				end
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
								includes:%s\n", tbl.shaderc, tbl.splat, tbl.stype, tbl.sopt, tbl.src, tbl.dest, inc)
						end
						err = err .. cmd_desc(tbl) .. "\n" .. ret
					end
				end
	
				return success, err
			end

			local success, err = true, ""
			for _, std in ipairs {prog.stdout, prog.stderr} do
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
