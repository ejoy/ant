local rootdir = os.getenv("ANTGE")
if rootdir == nil then
    print("ANTGE var not define, using current dir as root dir")
end

--print("root dir is : ", rootdir)

local argc = select('#', ...)
if argc < 3 then
    error(string.format("3 arguments need, input filename, output filename, rendertype"))
end

local infile = select(1, ...)
local outfile = select(2, ...)
local rendertype = select(3, ...)

dofile(rootdir .. "/libs/init.lua")

local toolset = require "editor.toolset"

local function compile(filename, outfilename, rendertype)
    local config = toolset.load_config()
	if next(config) then
		config.includes = {config.shaderinc, rootdir .. "/assets/shaders/src"}
        config.dest = outfilename
		local success, msg = toolset.compile(filename, config, rendertype)
		if not success then
			print(string.format("compile failed!\nsource file : %s, dest file : %s\nerror message : %s", 
				filename, outfile, msg))
		end
    end    
end

compile(infile, outfile, rendertype)