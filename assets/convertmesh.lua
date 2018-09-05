local rootdir = os.getenv("ANTGE")
if rootdir == nil then
    print("ANTGE var not define, using current dir as root dir")
end

--print("root dir is : ", rootdir)

local argc = select('#', ...)
if argc < 2 then
    error(string.format("2 arguments need, input filename, output filename"))
end

dofile(rootdir .. "/libs/init.lua")

local meshcreator = require "assimplua"
local path = require "filesystem.path"

local meshfiles = {}
path.listfiles("./meshes", meshfiles, {"fbx", "FBX", "bin"})
local modelutil = require "modelloader.util"
local config = modelutil.default_config()

for _, ff in ipairs(meshfiles) do
	local ext = path.ext(ff)
	local outfile = path.join("build", ff)
	if ext == "bin" then
		meshcreator.convert_BGFXBin(ff, outfile, config)
	elseif ext == "fbx" then
		meshcreator.convert_FBX(ff, outfile, config)
	else
		error(string.format("should not come here : %s", ff))
	end
end



