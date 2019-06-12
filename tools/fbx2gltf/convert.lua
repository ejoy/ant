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

local function is_PVPScene_obj(glbfile)
	local ff = fs.path(glbfile)
	while ff:string() ~= "" do
		local tt = ff:filename()
		if tt:string() == "PVPScene" then
			return true
		end

		ff = ff:parent_path()
	end
end

local function reset_PVPScene_object_root_pos(glbfile, scene)
	if not is_PVPScene_obj(glbfile) then
		return
	end

	local nodes = scene.nodes
	local filename = glbfile:filename()
	filename:replace_extension("")

	local function find_PVPScene_obj_root_node(scenenodes)
		for _, nodeidx in ipairs(scenenodes) do
			local node = nodes[nodeidx+1]
			if node.name == filename:string() then
				return node
			end

			if node.children then
				return find_PVPScene_obj_root_node(node.children)
			end
		end
	end

	local myrootnode = find_PVPScene_obj_root_node(scene.scenes[scene.scene+1].nodes)
	if myrootnode == nil then
		print(string.format("not found root name, no node name equal filename\n\
							 glb file : %s\n filename : %s", glbfile:string(), filename:string()))
		return
	end
	local m = myrootnode.matrix
	if m then
		m[13], m[14], m[15] = 0, 0, 0
	end

	local t = myrootnode.translation
	if t then
		t[1], t[2], t[3] = 0, 0, 0
	end
end


return function (files)
	local progs = {}
	for _, f in ipairs(files) do
		progs[#progs+1] = convert(f)
		generate_lkfile(f)
	end

	for _, prog in ipairs(progs) do
		prog:wait()
	end

	for _, f in ipairs(files) do
		local filename = fs.path(f):replace_extension("glb"):string()
		local glbdata = glbloader.decode(filename)
		local scene = glbdata.info

		if is_PVPScene_obj(f) then
			reset_PVPScene_object_root_pos(fs.path(f):replace_extension(".glb"), scene)
		end

		glbloader.encode(filename, glbdata)
	end
end