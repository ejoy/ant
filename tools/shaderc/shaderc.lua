--[[
    lua.exe .\tools\shaderc\main.lua 
        .Windows_DIRECT3D11
        .\packages\resources\shaders\mesh\fs_colormesh.sc 
        .\abc.bin 
]]

local fs = require "filesystem.local"
local fvpkg = import_package "ant.fileconvert"
local toolset = fvpkg.shader_toolset

for i, a in ipairs(arg) do
	if a == "--bin=msvc" then
		table.remove(arg, i)
		break
	end
end

local identity, input, output, macros, includes = table.unpack(arg)
if includes == nil then
	includes = {}
end
includes[#includes+1] = fs.current_path() / "packages/resources/shaders"

local success, err = toolset.compile{
	identity = identity,
	srcfile = fs.path(input),
	outfile = fs.path(output),
    includes = includes,
    macros = macros,
}

if success then
	print("success!")
else
	print("failed! error : ", err)
end
