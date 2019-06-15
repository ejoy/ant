package.path = "./tools/convert_unity_scene/?.lua;./tools/fbx2gltf/?.lua;./tools/?.lua;./packages/glTF/?.lua;./?.lua;libs/?.lua;libs/?/?.lua"
package.cpath = "projects/msvc/vs_bin/x64/Debug/?.dll"


local fs = require "filesystem.local"

local viking_projpath = fs.path "test/samples/unity_viking"
local worldfile = viking_projpath / "Assets/scene/viking.lua"

local util =require "convert_unity_scene.util"

local world = util.loadworld(worldfile)

local groups = {}

local function classify_mesh_reference(scene, entitylist, parent)
	for _, e in ipairs(entitylist) do
		local meshidx = e.Mesh
		if meshidx and e.Name:match "[Cc]ollider" then
			local group = groups[assert(parent).Name]
			if group == nil then
				group = {}
				groups[parent.Name] = group
			end

			local meshlist = group[meshidx]
			if meshlist == nil then
				meshlist = {}
				group[meshidx] = meshlist
			end

			meshlist[#meshlist+1] = {
				transform = {
					s=e.Scl, r=e.Rot, t=e.Pos,
				},
				material_indices = e.Mats,
				name = e.Name,
			}

			assert(e.Ent == nil)
			return true
		end

		if e.Ent then
			if classify_mesh_reference(scene, e.Ent, e) then
				return true
			end
		end
	end
end

for _, s in ipairs(world)do
	classify_mesh_reference(s, s.Ent)
end

local scene = world[1]
for groupname, group in pairs(groups) do
	print("group name:", groupname)
	for meshidx, meshlist in pairs(group)do
		local meshpath = scene.Meshes[meshidx]
		print("mesh reference:", meshpath)
		for _, mesh in ipairs(meshlist)do
			print("mesh name:", mesh.name)
			local function print_transform(trans)
				local function print_list(l)
					local t = {}
					for _, v in ipairs(l) do
						t[#t+1] = v
					end

					print("[" .. table.concat(t, ',') .. "]")
				end

				print_list(trans.Scl)
				print_list(trans.Rot)
				print_list(trans.Pos)
			end

			print_transform(mesh.transform)
			local function print_material(material_indices)
				local t = {}
				for _, mi in ipairs(material_indices) do
					t[#t+1] = mi
				end
				print("material indices:[" .. table.concat(t, ',') .. "]")
			end
			print_material(mesh.material_indices)
		end
	end
	
end