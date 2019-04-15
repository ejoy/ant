local ecs = ...
local world = ecs.world

ecs.import "ant.terrain"

local fs = require "filesystem"

local terrain_test = ecs.system "terrain_test"
terrain_test.depend 'init_loader'

function terrain_test:init()
	local terrainfolder = fs.path '//ant.resources' / 'terrain'
	local function create_properties(basetexpath, masktexpath)
		return {
			textures = {
				s_baseTexture = { name = "base texture", type = "texture", stage = 0, 
					ref_path = terrainfolder / basetexpath},
				s_maskTexture = { name = "mask texture", type = "texture", stage = 1, 
					ref_path = terrainfolder / masktexpath},
			}
		}
	end

	world:create_entity {
        material = {
            content = {
                {
					ref_path = terrainfolder / 'terrain.material',
					properties = create_properties("ground_099-512.dds", "pvp2_mask_a.dds"),
                },
                {
					ref_path = terrainfolder / 'terrain_mask.material',
					properties = create_properties("Scene_Texture_Terrain_BD_SOIL_0070_1.dds", "pvp2_mask_r.dds")
                },
                {
					ref_path = terrainfolder / 'terrain_mask.material',
					properties = create_properties("BH-Scene-JiangJunZong-Wall-02-D.dds", "pvp2_mask_g.dds")
                },
                {
					ref_path = terrainfolder / 'terrain_mask.material',
					properties = create_properties("Scene_Texture_Terrain_BD_ROCK_040_1.dds", "pvp2_mask_b.dds")
                }
            }
        },
        transform = {
            s = {1, 1, 1, 0},
            r = {0, 0, 0, 0},
            t = {-147,0.25,-225,1},
        },
        terrain = {
            ref_path = terrainfolder / 'pvp.terrain'
        },
        mesh = {},
        name = "pvp",
        can_render = true,
        main_view = true
	}
		
	world:create_entity {
        material = {
            content = {
                {
					ref_path = terrainfolder / 'terrain.material',
					properties = create_properties("ground_099-512.dds", "pvp2_mask_a.dds")
                },
                {
					ref_path = terrainfolder / 'terrain_mask.material',
					properties = create_properties("Scene_Texture_Terrain_BD_SOIL_0070_1.dds", "pvp2_mask_r.dds")
                },
                {
					ref_path = terrainfolder / 'terrain_mask.material',
					properties = create_properties("BH-Scene-JiangJunZong-Wall-02-D.dds", "pvp2_mask_g.dds")
                },
                {
					ref_path = terrainfolder / 'terrain_mask.material',
					properties = create_properties("Scene_Texture_Terrain_BD_ROCK_040_1.dds", "pvp2_mask_b.dds")
                }
            }
        },
        transform = {
            s = {1, 1, 1, 0},
            r = {0, 0, 0, 0},
            t = {60, 130, 60, 1},
        },
        terrain = {
            ref_path = terrainfolder / 'cibi.terrain'
        },
        mesh = {},
        name = "pvp",
        can_render = true,
        main_view = true
    }
end