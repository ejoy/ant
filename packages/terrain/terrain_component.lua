local ecs = ...
local world = ecs.world
local Physics = assert(world.args.Physics)

local assetpkg 	= import_package "ant.asset"
local assetmgr	= assetpkg.mgr

local renderpkg = import_package 'ant.render'
local declmgr 	= renderpkg.declmgr
local computil 	= renderpkg.components

local ms 		= import_package "ant.math".stack
local colliderutil = import_package "ant.bullet".util

local fs 		= require "filesystem"

local bgfx 		= require "bgfx"


local terrainshape = ecs.component "terrain_shape"
	.up_axis 	"int" (0)
	.flip_quad_edges "boolean" (false)

function terrainshape:delete()
	local handle = self.handle
	if handle then
		Physics:del_shape(self.handle)
	end
end

local terrain_collider = ecs.component "terrain_collider" {depend = {"transform", "terrain"}}
	.shape "terrain_shape"
	.collider "collider"

local function create_terrain_shape(shape, terraincomp)
	local terraininfo = assetmgr.get_terrain(terraincomp.ref_path)
	local terrain = terraininfo.handle
	local heightmap = terrain:heightmap_data()	
	local bounding = terrain:bounding()
	local aabb = bounding.aabb
	shape.handle = Physics:new_shape("terrain", {
		width = terraininfo.grid_width, height = terraininfo.grid_length, 
		heightmap_scale = 1.0, 
		min_height = aabb.min[2], max_height = aabb.max[2],
		heightmapdata = heightmap,
		up_axis = shape.up_axis, flip_quad_edges = shape.flip_quad_edges
	})

	local heightrange = aabb.max[2] - aabb.min[2]

	local scale = {terraininfo.width / terraininfo.grid_width, terraininfo.height / heightrange, terraininfo.length / terraininfo.grid_length}
	Physics:set_shape_scale(shape.handle, ms(scale, "P"))
end

function terrain_collider:postinit(e)	
	create_terrain_shape(self.shape, e.terrain)
	colliderutil.create_collider_comp(Physics, self.shape, self.collider, e.transform)
end

function terrain_collider:delete()
	self.shape.handle = nil -- collider own this handle, will delete in collider:delete function
end

local terraincomp =
    ecs.component_alias('terrain', 'resource') {
    depend = {'rendermesh', 'material'}
}

function terraincomp:postinit(e)
	local rm = e.rendermesh
	assert(self.asyn_load == nil)
    local terraininfo = assetmgr.get_terrain(self.ref_path)
    local terrainhandle = terraininfo.handle

    local numlayers = terraininfo.num_layers
    if numlayers ~= 1 + #e.material then
        error('terrain layer number is not equal material defined numbers')
	end

	local vb, ib = terrainhandle:buffer()
	local vbsize, ibsize = terrainhandle:buffer_size()
	local num_vertices, num_indices = terrainhandle:buffer_count()
	local decl = declmgr.get(terraininfo.declname)

	local dynamic = terraininfo.dynamic
	
	local create_vb = dynamic and bgfx.create_dynamic_vertex_buffer or bgfx.create_vertex_buffer
	local vbhandle = create_vb({"!", vb, vbsize}, decl.handle, dynamic and "wa" or "")

	local create_ib = dynamic and bgfx.create_dynamic_index_buffer or bgfx.create_index_buffer	
	local ibhandle = create_ib({ib, ibsize}, dynamic and "wad" or "d")

	local group = {
		vb = {
			handles = {
				vbhandle
			},
			start = 0,
			num = num_vertices,
		},
		ib = {
			handle = ibhandle,
			start = 0,
			num = num_indices,
		}
	}

	local meshscene = computil.assign_group_as_mesh()	
	-- using indirect draw can optimize this
	local groups = {}
	for _=1, numlayers do
		groups[#groups+1] = group
	end

	meshscene.scenes[1][1] = groups
	rm.reskey = assetmgr.register_resource(fs.path "//meshres/terrain.mesh", meshscene)
end