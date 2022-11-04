local ecs	= ...
local world = ecs.world
local w		= world.w
local iterrain = ecs.interface "iterrain"

local terrain_fields = {}
local terrain_width, terrain_height

local function calc_tf_idx(ix, iy, x)
    return (iy - 1) * x + ix
end

function iterrain.gen_terrain_field(width, height)
    local terrain_field = {}
    terrain_width  = width
    terrain_height = height
    for ih=1, terrain_height do
        for iw=1, terrain_width do
            local idx = (ih - 1) * terrain_width + iw
            terrain_field[idx] = {}
        end
    end
    terrain_fields = terrain_field     
end


function iterrain.create_roadnet_entity(x, y, type, dir)
    local idx = calc_tf_idx(x, y, terrain_width)
    local t,d
    if type == "U" then
        t = "U"
    elseif type == "I" then
        t = "I"
    elseif type == "L" then
        t = "L"
    elseif type == "T" then
        t = "T"
    elseif type == "X" then
        t = "X"
    else
        t = "D"
    end

    if dir == "N" then
        d = "1"
    elseif dir == "E" then
        d = "2"
    elseif dir == "S" then
        d = "3"
    elseif dir == "W" then
        d = "4"
    end

    terrain_fields[idx].type = t..d
end

function iterrain.create_terrain_entity()
    ecs.create_entity{
        policy = {
            "ant.scene|scene_object",
            "ant.terrain|shape_terrain",
            "ant.general|name",
        },
        data = {
            name = "shape_terrain_test",
            scene = {
                t = {0, 0, 0},
            },
            shape_terrain = {
                width = terrain_width,
                height = terrain_height,
                unit = 1.0,
                terrain_fields = terrain_fields,
                section_size = math.max(1, terrain_width > 4 and terrain_width//4 or terrain_width//2),
                material = "/pkg/ant.resources/materials/plane_terrain.material",
            },
        }
    }
end