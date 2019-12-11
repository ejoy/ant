local ecs = ...
local world = ecs.world

local renderpkg = import_package "ant.render"
local declmgr 	= renderpkg.declmgr
local computil 	= renderpkg.components

local assetpkg 	= import_package "ant.asset"
local assetmgr 	= assetpkg.mgr

local fs 		= require "filesystem"

local animodule = require "hierarchy.animation"
local bgfx 		= require "bgfx"

local m = ecs.policy "skinning"
m.require_component "animation"
m.require_component "skeleton"
m.require_component "rendermesh"
m.require_component "skinning_mesh"
m.require_transform "skinning"

local m = ecs.transform "skinning"
m.input "rendermesh"
m.input "animation"
m.output "skinning_mesh"

local function gen_mesh_assetinfo(sm)
	local smhandle = assetmgr.get_resource(sm.ref_path).handle

	local num_vertices, num_indices = smhandle:num_vertices(), smhandle:num_indices()

	local vbhandles = {}
	local create_buffer_op = {dynamic=bgfx.create_dynamic_vertex_buffer, static=bgfx.create_vertex_buffer}

	for _, buffertype in ipairs {"dynamic", "static"} do
		local layout = smhandle:layout(buffertype)
		local buffer, size = smhandle:buffer(buffertype)
		vbhandles[#vbhandles+1] = create_buffer_op[buffertype]({"!", buffer, size}, declmgr.get(layout).handle)
	end

	local idxbuffer, indices_sizebyte = smhandle:index_buffer()
	return computil.assign_group_as_mesh {
		vb = {
			handles = vbhandles,
			start = 0,
			num = num_vertices,
		},
		ib = {
			handle = bgfx.create_index_buffer {idxbuffer, indices_sizebyte},
			start = 0,
			num = num_indices,
		}
	}
end

function m.process(e)
	local rm = e.rendermesh
	local reskey = fs.path("//meshres/" .. e.skinning_mesh.ref_path:stem():string() .. ".mesh")
	rm.reskey = assetmgr.register_resource(reskey, gen_mesh_assetinfo(e.skinning_mesh))
end

-- skinning_mesh component is different from mesh component.
-- mesh component is used for render purpose.
-- skinning_mesh component is used for producing mesh component render data.
ecs.component_alias("skinning_mesh", "resource") {depend = {"rendermesh", "animation"}}


-- skinning system
local skinning_sys = ecs.system "skinning_system"

skinning_sys.depend "animation_system"

function skinning_sys:update()
	for _, eid in world:each("skinning_mesh") do
		local e = world[eid]

		local meshscene = assetmgr.get_resource(assert(e.rendermesh.reskey))

		local sm 		= assetmgr.get_resource(e.skinning_mesh.ref_path).handle
		local aniresult = e.animation.aniresult
		
		-- update data include : position, normal, tangent
		animodule.skinning(sm, aniresult)

		-- update mesh dynamic buffer
		local group = meshscene.scenes[1][1][1]
		local buffer, size = sm:buffer("dynamic")
		bgfx.update(group.vb.handles[1], 0, {"!", buffer, size})
	end
end