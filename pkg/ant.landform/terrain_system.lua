local ecs	= ...
local world = ecs.world
local w		= world.w
local iterrain = {}
local terrain_sys = ecs.system "terrain_system"
local iplane_terrain  = ecs.require "ant.landform|plane_terrain"

local function calc_shape_terrain(unit, width, height, shape_terrain)
    shape_terrain.width = width
    shape_terrain.height = height
    shape_terrain.unit = unit
    shape_terrain.terrain_field_max = width * height
    shape_terrain.section_size = math.min(math.max(1, width > 4 and width//4 or width//2), 32)
    shape_terrain.material = "/pkg/ant.landform/assets/materials/plane_terrain.material"
end


function iterrain.clear_terrain_field()
    local current_shape_terrain = w:first "shape_terrain st:update"
    local st = current_shape_terrain.st
    local planes, borders = st.plane_eids, st.border_eids
    for _, pid in ipairs(planes) do
        w:remove(pid)
    end
    for _, bid in ipairs(borders) do
        w:remove(bid)
    end
    st = {}
end

function iterrain.gen_terrain_field(width, height, offset, unit, render_layer)
    if not render_layer then render_layer = "opacity" end
    if not unit then unit = 10.0 end
    iplane_terrain.set_wh(width, height, offset, offset)
    local current_shape_terrain = w:first "shape_terrain st:update"
    local st = current_shape_terrain.st
    calc_shape_terrain(unit, width, height, st)
    iplane_terrain.init_plane_terrain(render_layer)
end

function terrain_sys:init()
    world:create_entity {
        policy = {
            "ant.scene|scene_object",
            "ant.landform|shape_terrain",
        },
        data = {
            scene = {
            },
            shape_terrain = true,
            st = {},
            on_ready = function()
            end,
        },
    }
end

return iterrain
