local ecs	= ...
local world = ecs.world
local w		= world.w
local iterrain = ecs.interface "iterrain"
local terrain_sys = ecs.system "terrain_system"
local iplane_terrain  = ecs.import.interface "ant.terrain|iplane_terrain"
local terrain_change = false
local terrain_fields = {}
local terrain_width, terrain_height
local shape_terrain = {}

local function calc_tf_idx(ix, iy, x)
    return (iy - 1) * x + ix
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
    shape_terrain.unit = 1.0
    shape_terrain.prev_terrain_fields = terrain_fields
    shape_terrain.section_size = math.max(1, terrain_width > 4 and terrain_width//4 or terrain_width//2)
    shape_terrain.material = "/pkg/ant.resources/materials/plane_terrain.material"
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
    calc_shape_terrain()
    iplane_terrain.set_wh(width, height)
    iplane_terrain.update_plane_terrain(shape_terrain)
end

function iterrain.create_roadnet_entity(create_list)
    for ii = 1, #create_list do
        local cl = create_list[ii]
        local x, y, type, dir = cl[1], cl[2], cl[3], cl[4]
        local idx = calc_tf_idx(x, y, terrain_width)
        local road = parse_terrain_type_dir(type, dir)
        terrain_fields[idx].type = road
    end
    terrain_change = true
end

function iterrain.update_roadnet_entity(update_list)
    for ii = 1, #update_list do
        local ul = update_list[ii]
        local x, y, type, dir = ul[1], ul[2], ul[3], ul[4]
        local idx = calc_tf_idx(x, y, terrain_width)
        local road = parse_terrain_type_dir(type, dir)
        terrain_fields[idx].type = road
    end
    terrain_change = true
end

function iterrain.delete_roadnet_entity(delete_list)
    for ii = 1, #delete_list do
        local dl = delete_list[ii]
        local x, y = dl[1], dl[2]
        local idx = calc_tf_idx(x, y, terrain_width)
        terrain_fields[idx] = {}
    end
    terrain_change = true
end

function terrain_sys:data_changed()
    if terrain_change then

        shape_terrain.prev_terrain_fields = terrain_fields
        for e in w:select "plane_terrain eid:in" do      
            w:remove(e)
        end

        iplane_terrain.update_plane_terrain(shape_terrain) 

        terrain_change = false
    end 

end

