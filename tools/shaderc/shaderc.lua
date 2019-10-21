--[[
    lua.exe .\tools\shaderc\main.lua 
        .Windows_DIRECT3D11
        .\packages\resources\shaders\mesh\fs_colormesh.sc 
        .\abc.bin 
]]

local fs = require "filesystem.local"
local fvpkg = import_package "ant.fileconvert"
local toolset = fvpkg.shader_toolset

local macros
local includes

local myarg = {}
for i, a in ipairs(arg) do
	local cfgname, cfgvalue = a:match "--(%w+)=(%w+)"
	if cfgname == nil then
		myarg[#myarg+1] = a
	else
		if cfgname == "macros" then
			macros = cfgvalue
		elseif cfgname == "includes" then
			includes = cfgvalue
		end
	end
end

local identity, input, output = table.unpack(myarg)
if includes == nil then
	includes = {}
end
includes[#includes+1] = fs.current_path() / "packages/resources/shaders"

local srcfile = fs.path(input)

if srcfile:extension():string():lower() == ".fx" then
	local success, msg = fvpkg.converter.fx(identity, srcfile, fs.path(output), function(filename)
		local vfs = require "vfs"
		return fs.path(vfs.realpath(filename))
	end)
	print("build:", success and "success" or "failed")
	print(msg)
else
	local success, err = toolset.compile{
		identity = identity,
		srcfile = srcfile,
		outfile = fs.path(output),
		includes = includes,
		macros = macros,
	}
	
	if success then
		print("success!")
	else
		print("failed! error : ", err)
	end
end
