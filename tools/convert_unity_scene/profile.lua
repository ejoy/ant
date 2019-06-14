package.path = "./tools/convert_unity_scene/?.lua;./tools/fbx2gltf/?.lua;./tools/?.lua;./packages/glTF/?.lua;./?.lua;libs/?.lua;libs/?/?.lua"
package.cpath = "projects/msvc/vs_bin/x64/Debug/?.dll"


local fs = require "filesystem.local"

local viking_projpath = fs.path "test/samples/unity_viking"
local worldfile = viking_projpath / "Assets/scene/viking.lua"

local util =require "convert_unity_scene.util"

local world = util.loadworld(worldfile)

local function iter_scene(scene, newscene, entitylist, new_entitylist, parent, new_parent)
	for _, e in ipairs(entitylist) do
		local new_e = {
			Pos = e.Pos,
			Scl = e.Scl,
			Rot = e.Rot,
			Name = e.Name
		}

		new_entitylist[#new_entitylist+1] = new_e

		if e.Ent then
			iter_scene(scene, newscene, e.Ent, new_e, e, new_e)
		end
		
		if e.Mesh and not e.Name:match "[Cc]ollider" then
			local ml = new_parent.mesh_list
			if ml == nil then
				ml = {}
				new_parent.mesh_list = ml
			end
			ml[#ml+1] = {mesh_idx = e.Mesh, transform = {s=e.Scl, r=e.Rot, t=e.Pos}}

			local materials = new_parent.materials
			if materials == nil then
				materials = {}
				new_parent.materials = materials
			end

			
		end
	end
end

for _, s in ipairs(world)do
	iter_scene(s, s.Ent)
end

