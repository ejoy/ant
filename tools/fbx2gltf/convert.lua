local fs = require "filesystem.local"
local glbloader = require "glb"

local subprocess = require "subprocess"

local function convert(filename)
	local fn = fs.path(filename)
	local commands = {
		"bin/FBX2glTF-windows-x64.exe",
		"-i", fn:string(),
		"-o", fn:replace_extension(""):string(),
		"-b", 
		"--compute-normals", "missing",
		stdout = true,
		stderr = true,
		hideWindow = true,
	}
	return subprocess.spawn(commands)	
end

local stringify = require "stringify"

local defaultlk_content = {
	config = {
		animation = {
			ani_list = 'all',
			cpu_skinning = true,
			load_skeleton = true
		},
		flags = {
			flip_uv = true,
			ib_32 = true,
			invert_normal = true
		},
		layout = {
			'p3|n30nIf|T|b|t20|c40'
		}
	},
	sourcetype = 'glb',
	type = 'mesh'
}

local function get_glb_lk_content(srclk)	
	if fs.exists(fs.path(srclk)) then
		local c = util.rawtable(srclk)
		c.sourcetype = "glb"
		return c
	end
	return defaultlk_content
end

local function generate_lkfile(filename)
	local fn = fs.path(filename)
	local srclkfile = fn:string() .. ".lk"
	local lkfile = fn:replace_extension(".glb"):string() .. ".lk"
	local c = get_glb_lk_content(srclkfile)
	local r = stringify(c, true, true)
	local glblk = io.open(lkfile, "w")
	glblk:write(r)
	glblk:close()
end

return function (files, cfg)
	local progs = {}
	for _, f in ipairs(files) do
		progs[#progs+1] = convert(f)
		generate_lkfile(f)
	end

	for _, prog in ipairs(progs) do
		prog:wait()
	end

	local postconvert = cfg.postconvert
	if postconvert then
		for _, f in ipairs(files) do
			local glbfilepath = fs.path(f):replace_extension("glb")
			local glbfilename = glbfilepath:string()
			local glbdata = glbloader.decode(glbfilename)
			local scene = glbdata.info

			postconvert(glbfilepath, scene)

			glbloader.encode(glbfilename, glbdata)
		end
	end
end