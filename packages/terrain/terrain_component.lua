local ecs = ...
local world = ecs.world

local assetpkg 	= import_package "ant.asset"
local assetmgr	= assetpkg.mgr

local renderpkg = import_package 'ant.render'
local declmgr 	= renderpkg.declmgr

local math3d = require "math3d"

local fs 		= require "filesystem"
local bgfx 		= require "bgfx"

local t = ecs.component "terrain"
["opt"].tile_width		"int" (2)
["opt"].tile_height		"int" (2)
["opt"].section_size	"int" (2)
["opt"].element_size	"int" (7)
["opt"].grid_unit		"real"(1)
["opt"].is_dynamic		"boolean"
["opt"].ref_path 		"respath"

local function is_power_of_2(n)
	if n ~= 0 then
		local l = math.log(n, 2)
		return math.ceil(l) == math.floor(l)
	end
end

local terrain_module = require "terrain"

local function tile_length(tc)
	return tc.section_size * tc.element_size
end

function t:init()
	if self.ref_path then
		self.tile_width = self.tile_width or 1
		self.tile_height = self.tile_height or 1
		self.section_size = self.section_size or 1
		self.element_size = self.element_size or 7

		local res = assetmgr.get_resource(self.ref_path)
		
	else
		if self.tile_width == nil or self.tile_height == nil then
			error(string.format("terrain data must provide if not from height field file"))
		end
		self.num_title = self.tile_width * self.tile_height
		self.num_section = self.num_title * self.section_size * self.section_size

		if not is_power_of_2(self.element_size+1) then
			error(string.foramt("element size must be power of two - 1:%d", self.element_size))
		end

		self.num_element = self.num_section * self.element_size * self.element_size
		local tlen = tile_length(self)

		local gridwidth, gridheight = self.tile_width * tlen, self.tile_height * tlen
		local hf_width, hf_height = gridwidth+1, gridheight+1
		local heightfield = {hf_width, hf_height}

		--TODO: need init aabb with heightfield data
		self.bounding = {aabb = math3d.ref(math3d.aabb({-hf_width, 0, -hf_height}, {hf_width, 0, hf_height}))}
		heightfield[3] = terrain_module.alloc_heightfield(hf_width, hf_height)
		self.grid_unit = self.grid_unit or 1

		self.heightfield = heightfield
		self.terrain_vertices, self.terrain_indices, self.terrain_normaldata = terrain_module.create(gridwidth, gridheight, self.grid_unit, heightfield)
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

local iterrain_class = ecs.interface "terrain"
local iterrain = world:interface "ant.terrain|terrain"

function iterrain_class.grid_width(tc)
	return tc.tile_width * tile_length(tc)
end

function iterrain_class.grid_height(tc)
	return tc.tile_height * tile_length(tc)
end

function iterrain_class.calc_min_max_height(tc)
	return terrain_module.calc_min_max_height(tc.heightfield)
end

function iterrain_class.heightfield(tc)
	return tc.heightfield
end

local trt = ecs.transform "terrain_render_transform"
trt.input "terrain"
trt.output "rendermesh"

trt.require_interface "ant.terrain|terrain"

function trt.process(e)
	local rm 			= e.rendermesh
	local terraincomp 	= e.terrain

	local meshscene = {
		sceneidx = 1,
		-- TODO: need define lod info
	}

	local gridwidth, gridheight = iterrain.grid_width(terraincomp), iterrain.grid_height(terraincomp)
	local numvertices = (gridwidth + 1) * (gridheight + 1)
	local pos_decl, normal_decl = declmgr.get "p3", declmgr.get "n3"
	local vb = {
		start = 0,
		num = numvertices,
		handles = {
			{
				handle = bgfx.create_vertex_buffer({"!", terraincomp.terrain_vertices, 0, numvertices * pos_decl.stride}, pos_decl.handle),
			},
			{
				handle = bgfx.create_vertex_buffer({"!", terraincomp.terrain_normaldata, 0, numvertices * normal_decl.stride}, normal_decl.handle)
			}
		},
	}

	local numindices = gridwidth * gridheight * 2 * 3
	local ib = {
		start = 0,
		num = numindices,
		handle = bgfx.create_index_buffer({terraincomp.terrain_indices, 0, numindices * 4}, "d"),
	}

	local scenes = {
		--scene:0
		{
			--mesh node:0
			{
				-- group:0
				{
					vb = vb,
					ib = ib,
				}
			}
		}
	}

	meshscene.scenes = scenes
	rm.reskey = assetmgr.register_resource(fs.path "//res.mesh/terrain.mesh", meshscene)
end