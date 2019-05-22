local ecs = ...
local world = ecs.world

local declmgr = import_package "ant.render".declmgr
local animodule = require "hierarchy.animation"
local bgfx = require "bgfx"

local gltfutil = import_package "ant.glTF".util

-- skinning_mesh component is different from mesh component.
-- mesh component is used for render purpose.
-- skinning_mesh component is used for producing mesh component render data.
local sm = ecs.component_alias("skinning_mesh", "resource") {depend = {"mesh", "animation"}}

local function gen_mesh_assetinfo(skinning_mesh_comp)
	local skinning_mesh = skinning_mesh_comp.assetinfo.handle

	local num_vertices, num_indices = skinning_mesh:num_vertices(), skinning_mesh:num_indices()

	local primitive = {
		attributes = {}
	}
	
	local namemapper = declmgr.name_mapper

	local function gen_vb_info(layout, num_vertices, bvidx, accessors, attributes)		
		local decl_ctremapper = gltfutil.decl_comptype_remapper
		local tc_remapper = gltfutil.type_count_remapper
		local offset = 0
		for elem in layout:gmatch "%w+" do
			local shortname = elem:sub(1, 1)
			local attribname = namemapper[shortname]
			attributes[attribname] = #accessors

			local elemtype = elem:sub(6, 6)			
			local elemcount = tonumber(elem:sub(2, 2))
			local normalized = elem:sub(4, 4) == "n"
			accessors[#accessors+1] = gltfutil.generate_accessor(bvidx, 
				decl_ctremapper[elemtype],
				tc_remapper[elemcount],
				offset,
				num_vertices,
				normalized)
		end
	end

	local accessors, bufferviews = {}, {}

	local create_buffer_op = {dynamic=bgfx.create_dynamic_vertex_buffer, static=bgfx.create_vertex_buffer}

	for _, buffertype in ipairs {"dynamic", "static"} do
		local layout = skinning_mesh:layout(buffertype)
		gen_vb_info(layout, num_vertices, #bufferviews, accessors, primitive.attributes)

		local buffer, size = skinning_mesh:buffer(buffertype)
		local stride = size // num_vertices
		local bv = gltfutil.generate_bufferview(nil, 0, size, stride, "vertex")
		bv.handle = create_buffer_op[buffertype]({"!", buffer, 1, size}, declmgr.get(layout).handle)
		bufferviews[#bufferviews+1] = bv
	end

	primitive.indices = #accessors

	local idxbuffer, indices_sizebyte = skinning_mesh:index_buffer()
	accessors[#accessors+1] 	= gltfutil.generate_index_accessor(#bufferviews, 0, num_indices)
	local bv = gltfutil.generate_index_bufferview(nil, 0, indices_sizebyte)
	bv.handle = bgfx.create_index_buffer({idxbuffer, 1, indices_sizebyte})
	bufferviews[#bufferviews+1] = bv
	

	return {
		handle = {
			scene = 0,
			scenes={{nodes={0}}},
			nodes = {{mesh=0}},
			meshes = {
				{
					primitives={primitive}
				}
			},
			accessors 	= accessors,
			bufferViews = bufferviews,
		}
	}

	-- local decls = {}
	-- local vb_handles = {}
	-- local vb_data = {"!", "", 1}
	-- for _, type in ipairs {"dynamic", "static"} do
	-- 	local layout = skinning_mesh:layout(type)
	-- 	local decl = declmgr.get(layout).handle
	-- 	table.insert(decls, decl)

	-- 	local buffer, size = skinning_mesh:buffer(type)
	-- 	vb_data[2], vb_data[3] = buffer, size
	-- 	if type == "dynamic" then
	-- 		table.insert(vb_handles, bgfx.create_dynamic_vertex_buffer(vb_data, decl))
	-- 	elseif type == "static" then
	-- 		table.insert(vb_handles, bgfx.create_vertex_buffer(vb_data, decl))
	-- 	end
	-- end

	-- local function create_idx_buffer()
	-- 	local idx_buffer, ib_size = skinning_mesh:index_buffer()	
	-- 	if idx_buffer then			
	-- 		return bgfx.create_index_buffer({idx_buffer, ib_size})
	-- 	end

	-- 	return nil
	-- end

	-- local ib_handle = create_idx_buffer()
	-- local bounding = skinning_mesh:bounding()
	-- return {
	-- 	handle = {
	-- 		bounding = bounding,
	-- 		groups = {
	-- 			{
	-- 				bounding = bounding,
	-- 				vb = {
	-- 					decls = decls,
	-- 					handles = vb_handles,
	-- 				},
	-- 				ib = {
	-- 					handle = ib_handle,
	-- 				}
	-- 			}
	-- 		}
	-- 	},			
	-- }
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