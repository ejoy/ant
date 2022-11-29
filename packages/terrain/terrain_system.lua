local ecs	= ...
local world = ecs.world
local w		= world.w
local iterrain = ecs.interface "iterrain"
local terrain_sys = ecs.system "terrain_system"
local iplane_terrain  = ecs.import.interface "ant.terrain|iplane_terrain"
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

local function parse_terrain_type_dir(type, dir)
    local t, d
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
    return t..d
end

local function calc_shape_terrain()
    shape_terrain.width = terrain_width
    shape_terrain.height = terrain_height
    shape_terrain.unit = 10.0
    shape_terrain.prev_terrain_fields = terrain_fields
    shape_terrain.section_size = math.min(math.max(1, terrain_width > 4 and terrain_width//4 or terrain_width//2), 16)
    shape_terrain.material = "/pkg/ant.resources/materials/plane_terrain.material"
end

function iterrain.gen_terrain_field(width, height, offset_x, offset_z)
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
    calc_shape_terrain()
    iplane_terrain.set_wh(width, height, offset_x, offset_z)
    iplane_terrain.init_plane_terrain(shape_terrain)
    terrain_width_offset  = offset_x
    terrain_height_offset = offset_z
end

function iterrain.create_roadnet_entity(create_list)
    for ii = 1, #create_list do
        local cl = create_list[ii]
        local x, y, type, dir = cl[1] + terrain_width_offset, cl[2] + terrain_height_offset, cl[3], cl[4]
        local idx = calc_tf_idx(x, y, terrain_width)
        local road = parse_terrain_type_dir(type, dir)
        terrain_fields[idx].type = road
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
        local x, y, type, dir = ul[1] + terrain_width_offset, ul[2] + terrain_height_offset, ul[3], ul[4]
        local idx = calc_tf_idx(x, y, terrain_width)
        local road = parse_terrain_type_dir(type, dir)
        terrain_fields[idx].type = road
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
        local x, y = dl[1] + terrain_width_offset, dl[2] + terrain_height_offset
        local idx = calc_tf_idx(x, y, terrain_width)
        terrain_fields[idx] = {}
        local section_idx = calc_section_idx(idx)
        if terrain_change[section_idx] == nil then
            tc_cnt = tc_cnt + 1
            terrain_change[section_idx] = true
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

        iplane_terrain.update_plane_terrain(shape_terrain, terrain_change) 

        terrain_change = {}
        tc_cnt = 0
    end 

end

