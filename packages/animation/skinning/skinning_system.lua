local ecs = ...
local world = ecs.world

local animodule = require "hierarchy.animation"
local bgfx = require "bgfx"

-- skinning_mesh component is different from mesh component.
-- mesh component is used for render purpose.
-- skinning_mesh component is used for producing mesh component render data.
local sm = ecs.component_alias("skinning_mesh", "resource") {depend = {"mesh", "animation"}}

local function gen_mesh_assetinfo(skinning_mesh_comp)
	local modelloader = import_package "ant.modelloader"

	local skinning_mesh = skinning_mesh_comp.assetinfo.handle

	local decls = {}
	local vb_handles = {}
	local vb_data = {"!", "", 1}
	for _, type in ipairs {"dynamic", "static"} do
		local layout = skinning_mesh:layout(type)
		local decl = modelloader.create_decl(layout)
		table.insert(decls, decl)

		local buffer, size = skinning_mesh:buffer(type)
		vb_data[2], vb_data[3] = buffer, size
		if type == "dynamic" then
			table.insert(vb_handles, bgfx.create_dynamic_vertex_buffer(vb_data, decl))
		elseif type == "static" then
			table.insert(vb_handles, bgfx.create_vertex_buffer(vb_data, decl))
		end
	end

	local function create_idx_buffer()
		local idx_buffer, ib_size = skinning_mesh:index_buffer()	
		if idx_buffer then			
			return bgfx.create_index_buffer({idx_buffer, ib_size})
		end

		return nil
	end

	local ib_handle = create_idx_buffer()

	return {
		handle = {
			groups = {
				{
					bounding = skinning_mesh:bounding(),
					vb = {
						decls = decls,
						handles = vb_handles,
					},
					ib = {
						handle = ib_handle,
					}
				}
			}
		},			
	}
end

function sm:postinit(e)
	local mesh = e.mesh
	assert(mesh.ref_path == nil)
	mesh.assetinfo = gen_mesh_assetinfo(e.skinning_mesh)
end

-- skinning system
local skinning_sys = ecs.system "skinning_system"

skinning_sys.depend "animation_system"

function skinning_sys:update()
	for _, eid in world:each("skinning_mesh") do
		local e = world[eid]

		local mesh 		= e.mesh.assetinfo.handle
		local sm 		= e.skinning_mesh.assetinfo.handle				
		local aniresult = e.animation.aniresult
		
		-- update data include : position, normal, tangent
		animodule.skinning(sm, aniresult)

		-- update mesh dynamic buffer
		assert(1 == #mesh.groups)
		local g = mesh.groups[1]
		local vb = g.vb		
		local buffer, size = sm:buffer("dynamic")
		local h = vb.handles[1]
		bgfx.update(h, 0, {"!", buffer, size})
	end
end