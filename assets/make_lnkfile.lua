local rootdir = os.getenv("ANTGE") or "."

local argc = select('#', ...)
if argc < 1 then
    error(string.format("3 arguments need, input filename, output filename, rendertype"))
end

local infile = select(1, ...)

dofile(rootdir .. "/libs/init.lua")

local path = require "filesystem.path"

local templates = {
	shader = [[
		shader_src = '%s'
	]],
	--[[
		p3 for position and need 3 element(x, y, z)
		t20 for texcoord, need 2 element(u, v) and in channel 0
		t31 for texcoord, need 3 element(u, v, w) and in channel 1
		c30 for color, need 3 element(r,g,b) and in channel 0
	]]
	mesh = [[
		mesh_src = '%s'
		config = { 
			layout = "p3|n|T|b|t20|c30",
			flags = {
				gen_normal = false,
				tangentspace = true,
			
				invert_normal = false,
				flip_uv = true,
				ib_32 = false,	-- if index num is lower than 65535
			},
			animation = {
				load_skeleton = true,
				ani_list = "all" -- or {"walk", "stand"}
			},
		}
	]]
}

local ext = path.ext(infile)

local template_filecontent
if ext == "sc" then
	template_filecontent = string.format(templates.shader, infile)
elseif ext == "fbx" then
	template_filecontent = string.format(templates.mesh, infile)
end

local winfile =  require "winfile"

local lnkfile = path.replace_ext(infile, "lk")
local lk = winfile.open(lnkfile, "wb")
lk:write(template_filecontent)
lk:close()