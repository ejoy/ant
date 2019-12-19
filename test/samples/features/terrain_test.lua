local ecs = ...
local world = ecs.world

ecs.import "ant.terrain"

local fs = require "filesystem"

local serialize = import_package "ant.serialize"

local terrain_test = ecs.system "terrain_test"
terrain_test.depend 'init_loader'

function terrain_test:init()
	local terrainfolder = fs.path '/pkg/ant.resources' / 'depiction' / 'terrain'
	local function create_properties(basetexpath, masktexpath)
		local texpath = terrainfolder / "textures"
		return {
			textures = {
				s_baseTexture = { 
					name = "base texture", 
					type = "texture", 
					stage = 0, 
					ref_path = texpath / basetexpath
				},
				s_maskTexture = { 
					name = "mask texture", 
					type = "texture",
					stage = 1,
					ref_path = texpath / masktexpath
				},
			}
		}
	end

	local function create_material()
	return {
		{
			ref_path = terrainfolder / 'terrain.material',
			properties = create_properties("ground_099-512.texture", "pvp2_mask_a.texture"),
		},
		{
			ref_path = terrainfolder / 'terrain_mask.material',
			properties = create_properties("Scene_Texture_Terrain_BD_SOIL_0070_1.texture", "pvp2_mask_r.texture")
		},
		{
			ref_path = terrainfolder / 'terrain_mask.material',
			properties = create_properties("BH-Scene-JiangJunZong-Wall-02-D.texture", "pvp2_mask_g.texture")
		},
		{
			ref_path = terrainfolder / 'terrain_mask.material',
			properties = create_properties("Scene_Texture_Terrain_BD_ROCK_040_1.texture", "pvp2_mask_b.texture")
		}
	}
	end

	world:create_entity {
		policy = {
			"render",
			"terrain",
			"terrain_collider",
			"name",
			"select",
		},
		data = {
			material = create_material(),
			transform = {
				s = {1, 1, 1, 0},
				r = {0, 0, 0, 0},
				t = {-147, 0.1,-225,1},
			},
			terrain = {
				ref_path = terrainfolder / 'pvp.terrain'
			},
			terrain_collider = {
				shape = {
					up_axis = 1,
					flip_quad_edges = false,
				},
				collider = {
					center = {0, 0, 0, 1},
					is_tigger = true,
					obj_idx = -1,
				},
			},
			rendermesh = {},
			name = "pvp terrain test",
			can_render = true,
			can_select = true,
			--can_cast  = true,
			serialize = serialize.create(),
		}
	}
end