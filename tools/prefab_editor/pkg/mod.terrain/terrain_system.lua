local ecs	= ...
local world = ecs.world
local w		= world.w
local iterrain = {}
local terrain_sys = ecs.system "terrain_system"
local iplane_terrain  = ecs.require "mod.terrain|plane_terrain"
local terrain_width, terrain_height
local shape_terrain = {}

local function calc_shape_terrain(unit, terrain_field)
    shape_terrain.width = terrain_width
    shape_terrain.height = terrain_height
    shape_terrain.unit = unit
    shape_terrain.prev_terrain_fields = terrain_field
    shape_terrain.section_size = math.min(math.max(1, terrain_width > 4 and terrain_width//4 or terrain_width//2), 32)
    shape_terrain.material = "/pkg/mod.terrain/assets/plane_terrain.material"
end

function iterrain.gen_terrain_field(width, height, offset, unit, render_layer)
    if not render_layer then render_layer = "opacity" end
    local terrain_field = {}
    terrain_width  = width
    terrain_height = height
    for ih=1, terrain_height do
        for iw=1, terrain_width do
            local idx = (ih - 1) * terrain_width + iw
            terrain_field[idx] = {}
        end
    end
    if not unit then
        unit = 10.0
    end
    calc_shape_terrain(unit, terrain_field)
    iplane_terrain.set_wh(width, height, offset, offset)
    iplane_terrain.init_plane_terrain(shape_terrain, render_layer)
    --iroad.set_args(width, height, offset, unit)
end

function terrain_sys:init()
    ecs.create_entity{
        policy = {
            "ant.scene|scene_object",
            "ant.general|name",
        },
        data = {
            scene = {
            },
            name          = "shape_terrain",
            shape_terrain = true,
            st = {},
            on_ready = function()
            end,
        },
    }
end

return iterrain
