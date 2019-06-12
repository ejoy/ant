local fs = require "filesystem.local"
local util = require "util"
local glbloader = require "glb"

local subprocess = require "subprocess"

local function convert(filename)
	local outfile = fs.path(filename):replace_extension("")	-- should not pass filename with extension, just filename without any extension
	local commands = {
		"bin/FBX2glTF-windows-x64.exe",
		"-i", filename:string(),
		"-o", outfile:string(),
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
	local lkpath = fs.path(srclk)
	if fs.is_regular_file(lkpath) then
		local c = util.raw_table(lkpath)
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
	local genlk = not cfg.no_lk
	for _, f in ipairs(files) do
		if f and fs.is_regular_file(f) then
			progs[#progs+1] = convert(f)
			if genlk then
				generate_lkfile(f)
			end
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