local bgfx = require "bgfx"
local fs = require "filesystem"
local glbloader = require "glbloader"

local loader = {}

local function is_glb(meshfile)
	meshfile:seek("set", 0)
	local content = meshfile:read(4) 
	meshfile:seek("set", 0)
	return content == "glTF"
end

function loader.load(filepath)
	if not __ANT_RUNTIME__ then
		assert(fs.exists(filepath .. ".lk"))
	end

	local meshfile = assert(fs.open(filepath, "rb"))

	assert(is_glb(meshfile), "only support glb file")
	return glbloader(meshfile)
end
return loader
