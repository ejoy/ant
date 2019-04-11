local ecs = ...
local world = ecs.world

ecs.import "ant.terrain"

local fs = require "filesystem"

local terrain_test = ecs.system "terrain_test"

function terrain_test:init()
	local terrainfolder = fs.path '//ant.resources' / 'terrain'
	world:create_entity {
        material = {
            content = {
                {
                    ref_path = terrainfolder / 'terrain.material'
                },
                {
                    ref_path = terrainfolder / 'terrain_mask.material'
                },
                {
                    ref_path = terrainfolder / 'terrain_mask.material'
                },
                {
                    ref_path = terrainfolder / 'terrain_mask.material'
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
                    ref_path = terrainfolder / 'terrain.material'
                },
                {
                    ref_path = terrainfolder / 'terrain_mask.material'
                },
                {
                    ref_path = terrainfolder / 'terrain_mask.material'
                },
                {
                    ref_path = terrainfolder / 'terrain_mask.material'
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