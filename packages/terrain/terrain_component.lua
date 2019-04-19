local ecs = ...
local world = ecs.world
local bgfx = require "bgfx"

local declmgr = import_package 'ant.render'.declmgr
local ms = import_package "ant.math".stack
local colliderutil = import_package "ant.bullet".util

local terraincomp =
    ecs.component_alias('terrain', 'resource') {
    depend = {'mesh', 'material'}
}

local Physics = assert(world.args.Physics)
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
	local terraininfo = terraincomp.assetinfo
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

local function create_buffer(terrainhandle, dynamic, declname)
    local vb, ib = terrainhandle:buffer()
	local vbsize, ibsize = terrainhandle:buffersize()

    local decl = declmgr.get(declname)

    local create_vb = dynamic and bgfx.create_dynamic_vertex_buffer or bgfx.create_vertex_buffer
	local create_ib = dynamic and bgfx.create_dynamic_index_buffer or bgfx.create_index_buffer
	local vbflags = dynamic and "wa" or ""
	local ibflags = dynamic and "wad" or "d"
    return create_vb({"!", vb, vbsize}, decl.handle, vbflags), create_ib({ib, ibsize}, ibflags)
end

function terraincomp:postinit(e)
    local mesh = e.mesh
    local terraininfo = e.terrain.assetinfo
    local terrainhandle = terraininfo.handle

    local numlayers = terraininfo.num_layers
    if numlayers ~= #e.material.content then
        error('terrain layer number is not equal material defined numbers')
    end

    local vbh, ibh = create_buffer(terrainhandle, terraininfo.dynamic, terraininfo.declname)

    local groups = {}
    for i = 1, numlayers do
        groups[#groups + 1] = {
            vb = {handles = {vbh}},
            ib = {handle = ibh}
        }
    end

    mesh.assetinfo = {
        handle = {
            bounding = terrainhandle:bounding(),
            groups = groups
        }
    }
end