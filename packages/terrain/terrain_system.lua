local ecs = ...
local world = ecs.world

local assetmgr = import_package "ant.asset"

local renderpkg = import_package 'ant.render'
local declmgr	= renderpkg.declmgr

local math3d	= require "math3d"
local terrain_module = require "terrain"

local ies = world:interface "ant.scene|ientity_state"

local t = ecs.component "terrain"
function t:init()
	self.tile_width		= self.tile_width	or 1
	self.tile_height	= self.tile_height	or 1
	self.section_size	= self.section_size or 2
	self.elem_size		= self.elem_size	or 7
	self.grid_unit		= self.grid_unit	or 1
	return self
end

local tm = ecs.transform "terrain_mesh"
function tm.process_prefab(e)
	local terrain = e._terrain
	local tilelen = terrain.section_size * terrain.elem_size
	local gridwidth, gridheight = terrain.tile_width * tilelen, terrain.tile_height * tilelen
	local pos_decl, normal_decl = declmgr.get "p3", declmgr.get "n3"
	local numindices = terrain.elem_size * terrain.elem_size * 2 * 3

	local renderdata = terrain_module.create_render_data()
	local indices = renderdata:init_index_buffer(terrain.elem_size, terrain.elem_size, gridwidth+1)
	local positions, normals = renderdata:init_vertex_buffer(gridwidth, gridheight, terrain.heightfield)
	terrain.renderdata = renderdata

	local numvertices = (gridwidth + 1) * (gridheight + 1)
	e.mesh = world.component "mesh" {
		vb = {
			start = 0,
			num = numvertices,
			{
				declname = "p3",
				memory = {positions, pos_decl.stride * numvertices},
			},
			{
				declname = "n3",
				memory = {normals, normal_decl.stride * numvertices},
			},
		},
		ib = {
			start = 0,
			num = numindices,
			flag = "d",
			memory = {indices, numindices * 4}
		}
	}
end

local bt = ecs.transform "build_terrain"

local function is_power_of_2(n)
	if n ~= 0 then
		local l = math.log(n, 2)
		return math.ceil(l) == math.floor(l)
	end
end

local function tile_length(t)
	return t.section_size * t.elem_size
end

function bt.process_prefab(e)
	local terrain = e.terrain

	if not is_power_of_2(terrain.elem_size+1) then
		error(string.foramt("element size must be power of two - 1:%d", terrain.elem_size))
	end

	local num_title	= terrain.tile_width * terrain.tile_height
	local t = {
		tile_width	= terrain.tile_width,
		tile_height	= terrain.tile_height,
		section_size= terrain.section_size,
		elem_size	= terrain.elem_size,
		grid_unit	= terrain.grid_unit,
		num_title	= num_title,
		num_section = num_title * terrain.section_size * terrain.section_size,
	}

	local tilelen = terrain.section_size * terrain.elem_size

	local gridwidth, gridheight = terrain.tile_width * tilelen, terrain.tile_height * tilelen

	local hf_width, hf_height = gridwidth+1, gridheight+1
	t.bounding = {aabb = math3d.ref(math3d.aabb({-hf_width, 0, -hf_height}, {hf_width, 0, hf_height}))}

	local hmwidth, hmheight, hmdata
	if terrain.heightmap then
		local hminfo = assetmgr.resource(terrain.heightmap)
		hmwidth, hmheight, hmdata = hminfo.width, hminfo.height, hminfo.data
	else
		hmwidth, hmheight = hf_width, hf_height
	end

	t.heightfield = {
		hmwidth, hmheight,
		terrain_module.alloc_heightfield(hmwidth, hmheight, hmdata)
	}
	e._terrain = t
end

local iterrain = ecs.interface "terrain"

function iterrain.grid_width(eid)
	local t = world[eid]._terrain
	return t.tile_width * tile_length(t)
end

function iterrain.grid_height(eid)
	local t = world[eid]._terrain
	return t.tile_height * tile_length(t)
end

function iterrain.min_max_height(eid)
	local t = world[eid]._terrain
	return t.min_max_height
end

function iterrain.heightfield(eid)
	local t = world[eid]._terrain
	return t.heightfield
end

local sma = ecs.action "section_mount"
function sma.init(prefab, idx, terraineid)
	local e = world[prefab[idx]]
	e.parent = terraineid
	local te = world[terraineid]
	local cp = te._cache_prefab

	local rc = e._rendercache
	rc.vb = {
		start = e.section_draw.vb_start,
		num = e.section_draw.vb_num,
		handles = cp.vb.handles,
	}
	rc.ib = cp.ib
end

local function create_render_terrain_entity(eid)
	local e = world[eid]
	if e.material == nil then
		error("terrain entity need material")
	end
	local terrain = e._terrain

	local sw = terrain.tile_width * terrain.section_size
	local sh = terrain.tile_height * terrain.section_size
	local section_vertexnum = (terrain.elem_size+1)
	local vertexwidth, vertexheight = (sw * terrain.elem_size)+1, (sh*terrain.elem_size)+1
	local numvertices = vertexwidth * vertexheight
	for isy=1, sh do
		local offset = (isy-1) * vertexwidth * terrain.elem_size
		for isx=1, sw do
			local start = offset + terrain.elem_size * (isx-1)
			world:create_entity{
				policy = {
					"ant.terrain|terrain_section_render",
					"ant.render|render",
					"ant.scene|hierarchy_policy",
					"ant.general|name",
				},
				data = {
					name = "section" .. isx .. isy,
					transform = {},
					state = ies.create_state "visible|cast_shadow",
					scene_entity=true,
					section_draw = {
						vb_start = start,
						vb_num = numvertices,
						sectionidx=isx + (isy-1) * sw,
					},
				},
				action = {
					section_mount = eid,
				}
			}
		end
	end
end

local ts = ecs.system "terrain_system"
local terrain_create_mb = world:sub{"component_register", "terrain"}
local terrain_delete_mb = world:sub{"remove_entity", "terrain"}
function ts.data_changed()
	for _, _, eid in terrain_create_mb:unpack() do
		local e = world[eid]
		create_render_terrain_entity(eid)
	end

	for _, _, eid in terrain_delete_mb:unpack() do
		local e= world[eid]

	end
end
