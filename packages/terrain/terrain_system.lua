local ecs = ...
local world = ecs.world

local assetmgr = import_package "ant.asset"

local renderpkg = import_package 'ant.render'
local declmgr	= renderpkg.declmgr

local math3d	= require "math3d"

local t = ecs.component "terrain"

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

		local tlen = tile_length(self)
		local gridwidth, gridheight = self.tile_width * tlen, self.tile_height * tlen
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
		local data = {}
		data.bounding = {aabb = math3d.ref(math3d.aabb({-hf_width, 0, -hf_height}, {hf_width, 0, hf_height}))}
		heightfield[3] = terrain_module.alloc_heightfield(hf_width, hf_height)
		self.grid_unit = self.grid_unit or 1

		data.heightfield = heightfield
		assert("terrain_module.create should create terrain object, it should include terrain data")
		data.terrain_vertices, data.terrain_indices, data.terrain_normaldata = terrain_module.create(gridwidth, gridheight, self.grid_unit, heightfield)

		self._data = data
	end
	return self
end

local iterrain_class = ecs.interface "terrain"
local iterrain

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

iterrain = world:interface "ant.terrain|terrain"

local trt = ecs.transform "terrain_transform"

function trt.process_entity(e)
	local terraincomp 	= e.terrain
	local terraindata = terraincomp._data

	local gridwidth, gridheight = iterrain.grid_width(terraincomp), iterrain.grid_height(terraincomp)
	local numvertices = (gridwidth + 1) * (gridheight + 1)
	local pos_decl, normal_decl = declmgr.get "p3", declmgr.get "n3"
	local numindices = gridwidth * gridheight * 2 * 3
	e.mesh = world.component "mesh" {
		vb = {
			start = 1,
			num = numvertices,
			{
				declname = "p3",
				memory = {terraindata.terrain_vertices, numvertices * pos_decl.stride},
			},
			{
				declname = "n3",
				memory = {terraindata.terrain_normaldata, numvertices * normal_decl.stride},
			},
		},
		ib = {
			start = 1,
			num = numindices,
			memory = {terraindata.terrain_indices, numvertices * 4},
		}
	}
end
