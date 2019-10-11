--[[
    lua.exe .\tools\shaderc\main.lua 
        .Windows_DIRECT3D11
        .\packages\resources\shaders\mesh\fs_colormesh.sc 
        .\abc.bin 
]]

local fs = require "filesystem.local"
local shaderc = import_package "ant.fileconvert".converter.shader
local identity, input, output = table.unpack(arg)
shaderc(identity, fs.path(input), nil, fs.path(output))
