local util = {}; util.__index = util
local fs = require "filesystem.local"

function util.list_files(subpath, filter, excludes, files)
	local prefilter = {}
	if type(filter) == "string" then
		for f in filter:gmatch("([.%w]+)") do
			local ext = f:upper()
			prefilter[ext] = true
		end
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

function util.raw_table(filepath)
	local env = {}
	local r = assert(fs.loadfile(filepath, "t", env))
	r()
	return env
end

function util.is_PVPScene_obj(glbfile)
	for m in glbfile:string():gmatch "[\\/]" do
		if m == "PVPScene" then
			return true
		end
	end
end

function util.reset_root_position(node)
	local m = node.matrix
	if m then
		m[13], m[14], m[15] = 0, 0, 0
	end

	local t = node.translation
	if t then
		t[1], t[2], t[3] = 0, 0, 0
	end
end

function util.reset_PVPScene_object_root_pos(glbfile, scene)
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

	util.reset_root_position(myrootnode)
end

return util