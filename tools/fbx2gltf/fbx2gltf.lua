package.path = "./?.lua;libs/?.lua;libs/?/?.lua;packages/glTF/?.lua"

local fs = require "filesystem.local"
local fbxsrcpath = fs.path(select(1, ...))

local function list_files(subpath, filter, excludes, files)
	local prefilter = {}
	for f in filter:gmatch("([.%w]+)") do
		local ext = f:upper()
		prefilter[ext] = true
	end

	local function list_fiels_1(subpath, filter, excludes, files)
		for p in subpath:list_directory() do
			local name = p:filename():string()
			if not excludes[name] then
				if fs.is_directory(p) then
					list_fiels_1(p, filter, excludes, files)
				else
					if type(filter) == "function" then
						if filter(p) then
							files[#files+1] = p
						end
					else
						local fileext = p:extension():string():upper()
						if prefilter[fileext] then
							files[#files+1] = p
						end
					end
					
				end
			end
		end		
	end

	list_fiels_1(subpath, filter, excludes, files)
end

local files = {}

for _, srcpath in ipairs {
	fs.path "packages/resources.binary", 
	fs.path "packages/resources" 
} do
	list_files(srcpath, ".fbx", {
		[".git"] = true, 
		[".repo"] = true, 
		[".vscode"] = true,
		[".vs"] = true
	}, files)
end

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

local stringify = require "packages/glTF/stringify"

local function rawtable(filepath)
	local env = {}
	local r = assert(loadfile(filepath, "t", env))
	r()
	return env
end

local function generate_lkfile(filename)
	local fn = fs.path(filename)
	local srclkfile = fn:string() .. ".lk"
	local lkfile = fn:replace_extension(".glb"):string() .. ".lk"

	local c = rawtable(srclkfile)
	c.sourcetype = "glb"
	local r = stringify(c, true, true)
	local glblk = io.open(lkfile, "w")
	glblk:write(r)
	glblk:close()
end

local function reset_PVPScene_object_root_pos(glbfile)
	local function is_PVPScene_obj()
		local ff = fs.path(glbfile)
		while ff:string() ~= "" do
			local tt = ff:filename()
			if tt:string() == "PVPScene" then
				return true
			end

			ff = ff:parent_path()
		end
	end

	if not is_PVPScene_obj() then
		return
	end

	
	local glbloader = require "glb"
	local glbdata = glbloader.decode(glbfile:string())
	local scene = glbdata.info
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

	glbloader.encode(glbfile:string(), glbdata)
end

local progs = {}
for _, f in ipairs(files) do
	progs[#progs+1] = convert(f)
	generate_lkfile(f)
end

for _, prog in ipairs(progs) do
	prog:wait()
end

for _, f in ipairs(files) do
	reset_PVPScene_object_root_pos(fs.path(f):replace_extension(".glb"))
end

