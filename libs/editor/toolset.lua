local fs = require "filesystem"
local fspath = require "filesystem.path"

local PATH = "ant"

local toolset = {}

local cwd = fs.currentdir()

if cwd == nil or cwd == "" then
	error("empty cwd!")
end

local default_toolset = {
	lua = cwd .. "/clibs/lua/lua.exe",
	shaderc = cwd .. "/3rd/bgfx/.build/win64_mingw-gcc/bin/shadercRelease.exe",
	shaderinc = cwd .. "/3rd/bgfx/src",
}

function toolset.load_config()
	local home = fs.personaldir()
	local toolset_path = string.format("%s/%s/toolset.lua", home, PATH)
	local ret = {}
	local f, err = loadfile(toolset_path, "t", ret)
	if f == nil then
		print(err)	
		for k, v in pairs(default_toolset) do
			ret[k] = v
		end
	else
		f()
	end	
	return ret
end

local function home_path()
	local home = fs.personaldir()
	local home_path = home .. "/" .. PATH
	local attrib = fs.attributes(home_path, "mode")
	if not attrib then
		assert(fs.mkdir(home_path))
	end
	assert(attrib == "directory")
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

local shader_type = {
	f = "fragment",
	v = "vertex",
	c = "compute",
}

local shader_opt = {
	d3d9 = "windows",
	d3d9_v = "-p vs_3_0 -O 3",
	d3d9_f = "-p ps_3_0 -O 3",
	d3d11 = "windows",
	d3d11_v = "-p vs_4_0 -O 3",
	d3d11_f = "-p ps_4_0 -O 3",
	d3d11_c = "-p cs_5_0 -O 1",
	glsl = "linux",
	glsl_v ="-p 120",
	glsl_f ="-p 120",
	glsl_c ="-p 430",
	ios = "ios",
	ios_v = "",
	ios_f = "",
	android = "android",
	android_v = "",
	android_f = "",
	android_c = "",
}

function toolset.compile(filename, paths, renderer)
	paths = paths or toolset.path

	if filename then
		local dest = paths.dest or filename:gsub("(%w+).sc", "%1") .. ".bin"

		local shaderc = paths.shaderc
		if shaderc and not fs.exist(shaderc)then
			error(string.format("bgfx shaderc path is privided, but file is not exist, path is : %s. \
								you can locate to ant folder, and run : bin/iup.lua tools/config.lua, to set the right path", shaderc))
		end

		local tbl = {
			shaderc = paths.shaderc,
			src = filename,
			dest = dest,
			inc = "",
			stype = nil,
			sopt = nil,
			splat = nil,
		}
		
		local includes = paths.includes
		if includes then
			local function gen_incpath(pp)
				return '-i "' .. pp .. '"'
			end

			local incpath = ""
			for _, p in ipairs(includes) do
				if not fs.exist(p) then
					error(string.format("include path : %s, but not exist!", p))
				end
				incpath = incpath .. gen_incpath(p) .. " "
			end
			if paths.not_include_examples_common == nil then				
				if paths.shaderinc and (not fs.exist(paths.shaderinc)) then
					error(string.format("bgfx shader include path is needed, \
										but path is not exist! path have been set : %s", paths.shaderinc))
				end

				local incexamplepath = fspath.join(paths.shaderinc, "../examples/common")
				if not fs.exist(incexamplepath) then
					error(string.format("example is needed, but not exist, path is : %s", incexamplepath))
				end
				
				incpath = incpath .. gen_incpath(incexamplepath)
			end

			tbl.inc = incpath
		end

		local vfc = filename:match "[/\\]([fvc])s_[^/\\]+.sc$"

		tbl.stype = assert(shader_type[vfc], vfc)
		tbl.splat = assert(shader_opt[renderer], renderer)
		tbl.sopt = assert(shader_opt[renderer .. "_" .. vfc])

		local command = string.gsub('$shaderc --platform $splat --type $stype $sopt -f "$src" -o "$dest" $inc',
			"%$(%w+)", tbl)

		local prog, err = io.popen(command .. "  2>&1")

		if not prog then
			return false, err
		else
			local ret = prog:read "a"
			prog:close()
			local success = ret and ret:find("error", 1, true) == nil or false
			return success, command .. "\n" .. ret
		end
	end
end

toolset.path = setmetatable(toolset.load_config(), { __index = default_toolset })
toolset.homedir = home_path()

return toolset
