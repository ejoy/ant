local rootdir = os.getenv("ANTGE") or "."

local numargs = select('#', ...)
local type
if numargs > 0 then
	type = select(1, ...)
end

dofile(rootdir .. "/libs/init.lua")

local modelutil = (import_package "ant.modelloader").util
local su = import_package "ant.serialize"
local fs = require "filesystem"


local templates = {
	shader = "shader_src = '%s'",
	mesh = [[
mesh_src = '%s'
config = %s
]]
}

local files = {}
if type == nil or type == "shaders" then
	fs.listfiles("shaders", files, function (filepath)
		local ext = filepath:extension()
		if ext:string() == "sc" then
			local filename = filepath:filename()
			local lowername = filename:string():lower()
			return lowername ~= "varying.def.sc"
		end
		return false
	end)
end

if type == nil or type == "mesh" then
	local exts = {"fbx", "FBX", "bin"}
	-- we assume all bin/fbx files should only exist in assets/build/meshes folder	
	fs.listfiles("build/meshes", files, exts)
	fs.listfiles("meshes", files, exts)
end

for _, ff in ipairs(files) do
	local ext = ff:extension():tostring():lower()

	local template_filecontent
	if ext == "sc" then
		template_filecontent = string.format(templates.shader, ff)
	elseif ext == "fbx" or ext == "bin" then
		local config = modelutil.default_config()
		local config_template = su.serialize(config, true)

		template_filecontent = string.format(templates.mesh, ff, config_template)
	end

	local lkfile = ff:replace_extension("lk")
	print("write lk : ", lkfile)
	local lk = io.open(lkfile, "wb")
	lk:write(template_filecontent)
	lk:close()
end
