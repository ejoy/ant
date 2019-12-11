local ecs = ...
local world = ecs.world

local renderpkg = import_package "ant.render"
local declmgr 	= renderpkg.declmgr
local computil 	= renderpkg.components

local mathpkg   = import_package "ant.math"
local ms		= mathpkg.stack
local mc 		= mathpkg.constant

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr

local fs 		= require "filesystem"

local animodule = require "hierarchy.animation"
local bgfx 		= require "bgfx"

local ozzmesh = ecs.component_alias("ozz_mesh", "resource") {depend = {"rendermesh", "animation"}}

local function gen_mesh_assetinfo(ozzmesh)
	local meshhandle = assetmgr.get_resource(ozzmesh.ref_path).handle

	local layouts = meshhandle:layout()
	local num_vertices = meshhandle:num_vertices()

	local function find_layout(shortname, layouts)
		for _, l in ipairs(layouts) do
			if shortname == l:sub(1, 1) then
				return l
			end
		end
	end

	local function generate_layout(shortnames, layouts)
		local layout = {}
		for _, sn in ipairs(shortnames) do
			local l = find_layout(sn, layouts)
			if l then
				layout[#layout+1] = l
			end
		end

		if next(layout) then
			return table.concat(layout, '|')
		end
	end

	local static_layout = generate_layout({'c', 't'}, layouts)
	local static_stride = declmgr.layout_stride(static_layout)
	local static_buffer = bgfx.memory_texture(num_vertices * static_stride)

	local static_vbhandle = {
		handle = bgfx.create_vertex_buffer(static_buffer)
	}

	local dynamic_layout = generate_layout({'p', 'n', 'T'}, layouts)
	local dynamic_stride = declmgr.layout_stride(dynamic_layout)
	local dynamic_vbhandle = {
		handle = bgfx.create_dynamic_vertex_buffer(num_vertices * dynamic_stride),
		updatedata = bgfx.memory_texture(num_vertices * dynamic_stride)
	}

	local meshgroup = {
		vb = {
			start = 0,
			num = num_vertices,
			handles = {
				static_vbhandle,
				dynamic_vbhandle,
			}
		}
	}

	local num_indices = meshhandle:num_indices()
	
	if num_indices ~= 0 then
		local indices_buffer, stride = meshhandle:index_buffer()
		meshgroup.ib = {
			start = 0,
			num = num_indices,
			handle = bgfx.create_index_buffer({indices_buffer, 1, num_indices * stride})
		}
	end

	return {
		sceneidx = 0,
		scenescale = 1.0,
		scenes = {
			{
				inverse_bind_pose = animodule.new_bind_pose(meshhandle:inverse_bind_pose()),
				meshgroup
			}
		}
	}
end

function ozzmesh:postinit(e)
	local rm = e.rendermesh

	local reskey = fs.path("//meshres/" .. self.ref_path:stem():string() .. ".mesh")
	rm.reskey = assetmgr.register_resource(reskey, gen_mesh_assetinfo(self))
end


local skinningmesh = ecs.component_alias("skinning_mesh", "resource") {depend = {"rendermesh", "animation", "skeleton"}}
.ref_path "respath"

function skinningmesh:postinit(e)
	local rm = e.rendermesh
	local res = assetmgr.get_resource(self.ref_path)
	local meshscene = computil.create_mesh_buffers(res)

	rm.reskey = assetmgr.register_resource(fs.path("//meshres/" .. self.ref_path:stem():string() .. ".mesh"), meshscene)

	return self
end

-- skinning system
local skinning_sys = ecs.system "skinning_system"

skinning_sys.depend "animation_system"

local function find_elem(name, layout_elems)
	assert(#name == 1)
	for _, elem in ipairs(layout_elems) do
		if elem:sub(1, 1) == name then
			return elem
		end
	end
end

local function create_node(elem, offset, layout_stride, pointer)
	local elemsize = declmgr.elem_size(elem)
	return {
		pointer,
		offset,
		layout_stride,
	}, offset + elemsize
end

local function layout_desc(elem_prefixs, layout_elems, layout_stride, pointer, offset)
	local desc = {}
	offset = offset or 1

	for _, elem_prefix in ipairs(elem_prefixs) do
		local elem = find_elem(elem_prefix, layout_elems)
		desc[#desc+1], offset = create_node(elem, offset, layout_stride, pointer, offset)
	end
	return desc
end

function skinning_sys:update()
	for _, eid in world:each "skinning_mesh" do
		local e = world[eid]

		local meshscene = assetmgr.get_resource(assert(e.rendermesh.reskey))
		local aniresult = e.animation.aniresult
		local meshres = assetmgr.get_resource(e.skinning_mesh.ref_path)

		for meshidx, meshnode in ipairs(meshscene.scenes[meshscene.sceneidx]) do
			local res_meshnode = meshres.scenes[meshscene.sceneidx][meshidx]
			for groupidx, group in ipairs(meshnode) do
				local res_group = res_meshnode[groupidx]

				local vb = group.vb
				for idx, handle in ipairs(vb.handles) do
					local updatedata = handle.updatedata
					if updatedata then
						local res_value = res_group.values[idx]
						local vbvalue = res_value.value
						local offset = res_value.start
						local declname = res_value.declname
						local layout_stride = declmgr.get(declname).stride
						local layout_elems = {}
						for elem in declname:gmatch "%w+" do
							layout_elems[#layout_elems+1] = elem
						end

						animodule.mesh_skinning(aniresult, meshnode.inverse_bind_pose_result,
							layout_desc({'p', 'n', 'T', 'w', 'i'}, layout_elems, layout_stride, vbvalue, offset),
							layout_desc({'p', 'n', 'T'}, layout_elems, layout_stride, updatedata), vb.num)

						bgfx.update(handle.handle, 0, {"!", updatedata, layout_stride * vb.num})
					end
				end
			end
		end

		-- local sm 		= assetmgr.get_resource(e.skinning_mesh.ref_path).handle
		-- local aniresult = e.animation.aniresult
		
		-- -- update data include : position, normal, tangent
		-- animodule.skinning(sm, aniresult)

		-- -- update mesh dynamic buffer
		-- local group = meshscene.scenes[1][1][1]
		-- local buffer, size = sm:buffer("dynamic")
		-- bgfx.update(group.vb.handles[1], 0, {"!", buffer, size})
	end
end