local ecs = ...
local world = ecs.world

local assetpkg 	= import_package "ant.asset"
local assetmgr	= assetpkg.mgr

local renderpkg = import_package 'ant.render'
local declmgr 	= renderpkg.declmgr
local computil 	= renderpkg.components

local ms 		= import_package "ant.math".stack

local mathbaselib=require "math3d.baselib"

local fs 		= require "filesystem"
local bgfx 		= require "bgfx"

-- local terrainshape = ecs.component "terrain_shape"
-- 	.up_axis 	"int" (0)
-- 	.flip_quad_edges "boolean" (false)

-- function terrainshape:delete()
-- 	local handle = self.handle
-- 	if handle then
-- 		Physics:del_shape(self.handle)
-- 	end
-- end

-- local terrain_collider = ecs.component "terrain_collider"
-- 	.shape "terrain_shape"
-- 	.collider "collider"

-- local function create_terrain_shape(shape, terraincomp)
-- 	local terraininfo = assetmgr.get_resource(terraincomp.ref_path)
-- 	local terrain = terraininfo.handle
-- 	local heightmap = terrain:heightmap_data()	
-- 	local bounding = terrain:bounding()
-- 	local aabb = bounding.aabb
-- 	shape.handle = Physics:new_shape("terrain", {
-- 		width = terraininfo.grid_width, height = terraininfo.grid_length, 
-- 		heightmap_scale = 1.0, 
-- 		min_height = aabb.min[2], max_height = aabb.max[2],
-- 		heightmapdata = heightmap,
-- 		up_axis = shape.up_axis, flip_quad_edges = shape.flip_quad_edges
-- 	})

-- 	local heightrange = aabb.max[2] - aabb.min[2]

-- 	local scale = {terraininfo.width / terraininfo.grid_width, terraininfo.height / heightrange, terraininfo.length / terraininfo.grid_length}
-- 	Physics:set_shape_scale(shape.handle, ms(scale, "P"))
-- end

-- function terrain_collider:delete()
-- 	self.shape.handle = nil -- collider own this handle, will delete in collider:delete function
-- end

-- ecs.component_alias('terrain', 'resource')

-- local terrainpolicy = ecs.policy "terrain"
-- terrainpolicy.require_component "rendermesh"
-- terrainpolicy.require_component "terrain"
-- terrainpolicy.require_transform "terrain"

-- local t = ecs.transform "terrain"
-- t.input "terrain"
-- t.output "rendermesh"

-- function t.process(e)
-- 	local rm = e.rendermesh
-- 	local terrain = e.terrain
--     local terraininfo = assetmgr.get_resource(terrain.ref_path)
--     local terrainhandle = terraininfo.handle

--     local numlayers = terraininfo.num_layers
--     if numlayers ~= 1 + #e.material then
--         error('terrain layer number is not equal material defined numbers')
-- 	end

-- 	local vb, ib = terrainhandle:buffer()
-- 	local vbsize, ibsize = terrainhandle:buffer_size()
-- 	local num_vertices, num_indices = terrainhandle:buffer_count()
-- 	local decl = declmgr.get(terraininfo.declname)

-- 	local dynamic = terraininfo.dynamic
	
-- 	local create_vb = dynamic and bgfx.create_dynamic_vertex_buffer or bgfx.create_vertex_buffer
-- 	local vbhandle = create_vb({"!", vb, 0, vbsize}, decl.handle, dynamic and "wa" or "")

-- 	local create_ib = dynamic and bgfx.create_dynamic_index_buffer or bgfx.create_index_buffer	
-- 	local ibhandle = create_ib({ib, 0, ibsize}, dynamic and "wad" or "d")

-- 	local group = {
-- 		vb = {
-- 			handles = {
-- 				vbhandle
-- 			},
-- 			start = 0,
-- 			num = num_vertices,
-- 		},
-- 		ib = {
-- 			handle = ibhandle,
-- 			start = 0,
-- 			num = num_indices,
-- 		}
-- 	}

-- 	local meshscene = computil.assign_group_as_mesh()	
-- 	-- using indirect draw can optimize this
-- 	local groups = {}
-- 	for _=1, numlayers do
-- 		groups[#groups+1] = group
-- 	end

-- 	meshscene.scenes[1][1] = groups
-- 	rm.reskey = assetmgr.register_resource(fs.path "//res.mesh/terrain.mesh", meshscene)
-- end

local t = ecs.component "terrain"
["opt"].tile_width		"int" (2)
["opt"].tile_height		"int" (2)
["opt"].section_size	"int" (7)
["opt"].element_size	"int" (15)
["opt"].is_dynamic		"boolean"
["opt"].ref_path 		"respath"

local function is_power_of_2(n)
	if n ~= 0 then
		local l = math.log(n, 2)
		return math.ceil(l) == math.floor(l)
	end
end

local terrain_module = require "terrain"

local function unit_length(tc)
	return tc.section_size * tc.element_size
end

function t:init()
	if self.ref_path then
		-- TODO
		self.tile_width = self.tile_width or 1
		self.tile_height = self.tile_height or 1
	else
		if self.tile_width == nil or self.tile_height == nil then
			error(string.format("terrain data must provide if not from height field file"))
		end
		self.num_title = self.tile_width * self.tile_height
		if not is_power_of_2(self.section_size+1) then
			error(string.format("section size must be power of two - 1:%d", self.section_size))
		end

		self.num_section = self.num_title * self.section_size * self.section_size

		if not is_power_of_2(self.element_size+1) then
			error(string.foramt("element size must be power of two - 1:%d", self.element_size))
		end

		self.num_element = self.num_section * self.element_size * self.element_size
		local unitlen = unit_length(self)
		self.bounding = mathbaselib.new_bounding(ms)
		self.terrain_vertices, self.terrain_indices, self.terrain_normaldata = terrain_module.alloc(self.tile_width * unitlen, self.tile_height * unitlen, nil, self.bounding)
	end
	return self
end


local t_p = ecs.policy "terrain_render"
t_p.require_component "terrain"
t_p.require_component "rendermesh"
t_p.require_component "transform"
t_p.require_component "material"
t_p.require_component "can_render"

t_p.require_transform "terrain_render_transform"

local trt = ecs.transform "terrain_render_transform"
trt.input "terrain"
trt.output "rendermesh"

local iterrain = ecs.interface "terrain"

function iterrain.grid_width(tc)
	return tc.tile_width * unit_length(tc)
end

function iterrain.grid_height(tc)
	return tc.tile_height * unit_length(tc)
end

function iterrain.calc_min_max_height(tc)
	return terrain_module.calc_min_max_height(iterrain.grid_width(tc), iterrain.grid_height(tc), tc.terrain_vertices)
end

function iterrain.heightfield_data(tc)
	return tc.terrain_vertices
end

function trt.process(e)
	local rm 			= e.rendermesh
	local terraincomp 	= e.terrain

	local meshscene = {
		sceneidx = 0,
		-- TODO: need define lod info
	}

	local it = world:interface "ant.terrain|terrain"
	local gridwidth, gridheight = it.grid_width(terraincomp), it.grid_height(terraincomp)
	local numvertices = (gridwidth + 1) * (gridheight + 1)

	local vb = {
		start = 0,
		num = numvertices,
		handles = {
			{
				handle = bgfx.create_vertex_buffer({"!", terraincomp.terrain_vertices, 0, numvertices}, declmgr.get("p3").handle),
			},
			{
				handle = bgfx.create_vertex_buffer({"!", terraincomp.terrain_normaldata, 0, numvertices}, declmgr.get("n3").handle)
			}
		},
	}

	local numindices = gridwidth * gridheight * 3
	local ib = {
		start = 0,
		num = numindices,
		handle = bgfx.create_index_buffer({terraincomp.terrain_indices, 0, numindices}),
	}

	local scenes = {
		--scene:0
		{
			--mesh node:0
			{
				vb = vb,
				ib = ib,
			}
		}
	}

	meshscene.scenes = scenes
	rm.reskey = assetmgr.register_resource(fs.path "//res.mesh/terrain.mesh", meshscene)
end