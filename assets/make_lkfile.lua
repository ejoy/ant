local rootdir = os.getenv("ANTGE") or "."

local numargs = select('#', ...)
local type
if numargs > 0 then
	type = select(1, ...)
end

dofile(rootdir .. "/libs/init.lua")

local path = require "filesystem.path"

local winfile =  require "winfile"

local modelutil = require "modelloader.util"
local su = require "serialize.util"

local config_template = su.serialize(modelutil.default_config())

local templates = {
	shader = "shader_src = '%s'",
	mesh = [[
mesh_src = '%s'
config = %s
]]
}

local files = {}
if type == nil or type == "shaders" then
	path.listfiles("shaders", files, function (filepath)
		local ext = path.ext(filepath)
		if ext == "sc" then
			return path.filename(filepath):lower() ~= "varying.def.sc"
		end
		return false
	end)
end

if type == nil or type == "mesh" then
	local exts = {"fbx", "FBX", "bin"}
	-- we assume all bin/fbx files should only exist in assets/build/meshes folder	
	path.listfiles("build/meshes", files, exts)
end

for _, ff in ipairs(files) do
	local ext = path.ext(ff):lower()

	local template_filecontent
	if ext == "sc" then
		template_filecontent = string.format(templates.shader, ff)
	elseif ext == "fbx" or ext == "bin" then
		template_filecontent = string.format(templates.mesh, ff, config_template)
	end

	local lkfile = path.replace_ext(ff, "lk")
	print("write lk : ", lkfile)
	local lk = winfile.open(lkfile, "wb")
	lk:write(template_filecontent)
	lk:close()
end
