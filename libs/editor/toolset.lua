local fs = require "filesystem"

local PATH = "ant"

local toolset = {}

local default_toolset = {
	lua = "lua.exe",
	shaderc = "shadercRelease.exe",
}

function toolset.load_config()
	local home = fs.personaldir()	
	local toolset_path = string.format("%s/%s/toolset.lua", home, PATH)
	local ret = {}
	local f,err = loadfile(toolset_path, "t", ret)
	if f then
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

function toolset.compile(filename, paths, stype, smodel)
	paths = paths or toolset.path

	if filename then
		print("dest : ", paths.dest)
		local dest = paths.dest or filename:gsub("(%w+).sc", "%1") .. ".bin"		
		local tbl = {
			shaderc = paths.shaderc,
			src = filename,
			dest = dest,
			inc = "",
			stype = nil,
			smodel = nil
		}
		if paths.shaderinc then
			tbl.inc = '-i "' .. paths.shaderinc .. '"'
		end

		local vf = filename:match "[/\\]([fv])s_[^/\\]+.sc$"
		local t = {
			f={t="fragment", m="ps_4_0"}, 
			v={t="vertex", m="vs_4_0"}
		}
		local c = t[vf]
		
		tbl.stype = stype or (c and c.t)
		tbl.smodel = smodel or (c and c.m)

		if tbl.stype == nil or tbl.smodel == nil then
			return false, "stype or smodel is nil or shader name should be fs_*.sc or vs_*.sc"
		end

		local command = string.gsub('$shaderc --platform windows --type $stype -p $smodel -O 3 -f "$src" -o "$dest" $inc',
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
