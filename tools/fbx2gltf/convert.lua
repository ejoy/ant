local fs = require "filesystem.local"
local util = require "fbx2gltf.util"
local glbloader = require "glb"

local subprocess = require "subprocess"

local function convert(filename)
	local outfile = fs.path(filename):replace_extension("")	-- should not pass filename with extension, just filename without any extension
	local commands = {
		"bin/msvc/FBX2glTF-windows-x64.exe",
		"-i", filename:string(),
		"-o", outfile:string(),
		"-b", 
		"--compute-normals", "missing",
		"--pbr-metallic-roughness",
		stdout = true,
		stderr = true,
		hideWindow = true,
	}
	return subprocess.spawn(commands)	
end

return function (files, cfg)
	local progs = {}
	for _, f in ipairs(files) do
		if f and fs.is_regular_file(f) then
			progs[#progs+1] = convert(f)
		end
	end

	for _, prog in ipairs(progs) do
		prog:wait()
	end

	local postconvert = cfg.postconvert
	if postconvert then
		for _, f in ipairs(files) do
			if f then
				local glbfilepath = fs.path(f):replace_extension("glb")
				local glbfilename = glbfilepath:string()
				local glbdata = glbloader.decode(glbfilename)
				local scene = glbdata.info

				postconvert(glbfilepath, scene)

				glbloader.encode(glbfilename, glbdata)
			end
		end
	end
end