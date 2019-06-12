package.path = "./tools/convert_unity_scene/?.lua;./tools/?.lua;./?.lua;libs/?.lua;libs/?/?.lua"
package.cpath = "projects/msvc/vs_bin/x64/Debug/?.dll"

local fs = require "filesystem.local"

local scenefile = fs.path "test/samples/unity_viking/Assets/scene/viking.lua"

if not fs.exists(scenefile) then
	error(string.format("file not found:%s", scenefile:string()))
end

local r, err = loadfile(scenefile:string())
if r == nil then
	error(string.format("load file error:", err))
end
local scene = r()

local fbxfilepaths = {}
for _, fn in ipairs(scene.Meshes) do
	fbxfilepaths = fs.path(fn)
end

local maxdepth = 2
local function is_root_node(node, level)
	return level <= maxdepth and node.name:match "RootNode"
end
local function is_geometric_node(node)
	return node.mesh and node.name:match "_Geometric$"
end

local function reset_transform(node)
	if node.matrix then
		node.matrix = {
			1, 0, 0, 0,
			0, 1, 0, 0,
			0, 0, 1, 0,
			0, 0, 0, 1,
		}
	else
		local s, r, t = node.scale, node.rotation, node.translation
		if s then
			s[1], s[2], s[3] = 1, 1, 1
		end
		if r then
			assert(#r==4)	--queration
			r[1], r[2], r[3], r[4] = 0, 0, 0, 1
		end
		if t then
			t[1], t[2], t[3] = 0, 0, 0
		end
	end
end

local function reset_scene_transform(scene)
	local function iter_nodes(nodes, level)
		level = level or 1
		for _, nodeidx in ipairs(nodes)do
			local node = scene.nodes[nodeidx+1]
			if is_root_node(node, level) or 
				is_geometric_node(node) then
				reset_transform(node)
			end

			if node.children then
				iter_nodes(node.children, level+1)
			end
		end
	end

	iter_nodes(scene.scenes[scene.scene+1].nodes, 1)
end

-- local function bake_transform_to_vertices(scene)

-- end

local fbxconvert = require "fbx2gltf.convert"
fbxconvert(fbxfilepaths, {
	no_lk = true,
	postconvert = function (filepath, scene)
		reset_scene_transform(scene)
	end
})

