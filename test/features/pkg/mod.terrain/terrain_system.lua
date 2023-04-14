local ecs	= ...
local world = ecs.world
local w		= world.w
local iterrain = ecs.interface "iterrain"
local terrain_sys = ecs.system "terrain_system"
local iplane_terrain  = ecs.import.interface "mod.terrain|iplane_terrain"
local terrain_change = {}
local tc_cnt = 0
local terrain_fields = {}
local terrain_width, terrain_height
local shape_terrain = {}
local terrain_width_offset = 0
local terrain_height_offset = 0

local function calc_tf_idx(ix, iy, x)
    return iy * x + ix + 1
end

local function calc_section_idx(idx)
    local width, height = shape_terrain.width, shape_terrain.height
    local size = shape_terrain.section_size
    local x = (idx - 1) %  width
    local y = (idx - 1) // height
    return y // size * (height / size)  + x // size + 1
end

local TERRAIN_TYPES<const> = {
    road1 = "1",
    road2 = "2",
    road3 = "3",
    mark1 = "4",
    mark2 = "5",
    mark3 = "6"
}

local TERRAIN_DIRECTIONS<const> = {
    N = "1",
    E = "2",
    S = "3",
    W = "4",
}

local TERRAIN_ZONE_COLORS<const> = {
    opaque = 0,
    blue = 1
}

local function parse_terrain_type_dir(layers, tname)
    local type, shape, dir = tname..layers[tname].type, layers[tname].shape, layers[tname].dir
    local t<const> = assert(TERRAIN_TYPES[type])
    local s<const> = shape or "D"
    local d<const> = assert(TERRAIN_DIRECTIONS[dir])
    return ("%s%s%s"):format(t, s, d)
end

local function calc_shape_terrain(unit)
    shape_terrain.width = terrain_width
    shape_terrain.height = terrain_height
    shape_terrain.unit = unit
    shape_terrain.prev_terrain_fields = terrain_fields
    shape_terrain.section_size = math.min(math.max(1, terrain_width > 4 and terrain_width//4 or terrain_width//2), 32)
    shape_terrain.material = "/pkg/mod.terrain/assets/plane_terrain.material"
end

function iterrain.gen_terrain_field(width, height, offset, unit)
    local terrain_field = {}
    terrain_width  = width
    terrain_height = height
    for ih=1, terrain_height do
        for iw=1, terrain_width do
            local idx = (ih - 1) * terrain_width + iw
            terrain_field[idx] = {
                layers = {},
                road_type = 0.0,
                road_direction = 0.0,
                road_shape = 0.0,
                mark_type  = 0.0,
                mark_direction = 0.0,
                mark_shape = 0.0 
            }
        end
    end
    terrain_fields = terrain_field
    if not unit then
        unit = 10.0
    end
    calc_shape_terrain(unit)
    --iplane_terrain.set_wh(width, height, offset_x, offset_z)
    iplane_terrain.set_wh(width, height, offset, offset)
    iplane_terrain.init_plane_terrain(shape_terrain)
    terrain_width_offset  = offset
    terrain_height_offset = offset
end

function iterrain.create_roadnet_entity(create_list)
    for ii = 1, #create_list do
        local cl = create_list[ii]
        local x, y = cl.x + terrain_width_offset, cl.y + terrain_height_offset
        local layers = cl.layers
        local idx = calc_tf_idx(x, y, terrain_width)
        local road_layer, mark_layer
        if layers == nil then
            road_layer = nil
            mark_layer = nil
        end

        if layers and layers.road ~= nil then
            road_layer = parse_terrain_type_dir(layers, "road")
        else
            road_layer = nil
        end

        if layers and layers.mark ~= nil then
            mark_layer = parse_terrain_type_dir(layers, "mark")
        else
            mark_layer = nil
        end

        terrain_fields[idx].layers = {
            [1] = road_layer,
            [2] = mark_layer
        }
        local section_idx = calc_section_idx(idx)
        if terrain_change[section_idx] == nil then
            tc_cnt = tc_cnt + 1
            terrain_change[section_idx] = true
        end
    end
end

function iterrain.update_roadnet_entity(update_list)
    for ii = 1, #update_list do
        local ul = update_list[ii]
        local x, y = ul.x + terrain_width_offset, ul.y + terrain_height_offset
        local layers = ul.layers;
        local idx = calc_tf_idx(x, y, terrain_width)
        local road_layer, mark_layer
        if layers == nil then
            road_layer = nil
            mark_layer = nil
        end

        if layers and layers.road ~= nil then
            road_layer = parse_terrain_type_dir(layers, "road")
        else
            road_layer = nil
        end

        if layers and layers.mark ~= nil then
            mark_layer = parse_terrain_type_dir(layers, "mark")
        else
            mark_layer = nil
        end

        terrain_fields[idx].layers = {
            [1] = road_layer,
            [2] = mark_layer
        }
        local section_idx = calc_section_idx(idx)
        if terrain_change[section_idx] == nil then
            tc_cnt = tc_cnt + 1
            terrain_change[section_idx] = true
        end
    end
end

function iterrain.delete_roadnet_entity(delete_list)
    for ii = 1, #delete_list do
        local dl = delete_list[ii]
        local x, y = dl.x + terrain_width_offset, dl.y + terrain_height_offset
        local idx = calc_tf_idx(x, y, terrain_width)
        terrain_fields[idx] = {
            layers = {},
            road_type = 0.0,
            road_direction = 0.0,
            road_shape = 0.0,
            mark_type  = 0.0,
            mark_direction = 0.0,
            mark_shape = 0.0
        }
        local section_idx = calc_section_idx(idx)
        if terrain_change[section_idx] == nil then
            tc_cnt = tc_cnt + 1
            terrain_change[section_idx] = true
        end
    end
end

function iterrain.update_zone_entity(update_list)
    for ii = 1, #update_list do
        local ul = update_list[ii]
        local x, y = ul.x + terrain_width_offset, ul.y + terrain_height_offset
        local idx = calc_tf_idx(x, y, terrain_width)
        terrain_fields[idx].zone_color = TERRAIN_ZONE_COLORS[ul.zone_color]
        local section_idx = calc_section_idx(idx)
        if terrain_change[section_idx] == nil then
            tc_cnt = tc_cnt + 1
            terrain_change[section_idx] = true
        end
    end
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

function iterrain.is_stone_mountain(width, height)
    
    for e in w:select "shape_terrain st:update eid:in" do
        local st = e.st
        if st.prev_terrain_fields == nil then
            error "need define terrain_field, it should be file or table"
        end
        local cur_idx=  width + height * terrain_width + 1  --width and heights' value from game world 0
        if st.prev_terrain_fields[cur_idx].is_sm then
            return true
        else
            return false
        end

    end
end

function terrain_sys:data_changed()
    if tc_cnt ~= 0 then

        shape_terrain.prev_terrain_fields = terrain_fields

        for e in w:select "plane_terrain eid:in section_index:in" do
            local section_idx = e.section_index
            if terrain_change[section_idx] == true and tc_cnt ~= 0 then
                tc_cnt = tc_cnt - 1
                w:remove(e) 
            end      
        end

        iplane_terrain.update_plane_terrain(terrain_change) 

        terrain_change = {}
        tc_cnt = 0
    end 

end

