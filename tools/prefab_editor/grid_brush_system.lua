local ecs = ...
local world = ecs.world
local utils = require "mathutils"(world)
local camera_mgr = require "camera_manager"(world)
local math3d = require "math3d"
local iom = world:interface "ant.objcontroller|obj_motion"
local iss = world:interface "ant.scene|iscenespace"
local computil = world:interface "ant.render|entity"

local brush_sys = ecs.system "grid_brush_system"

local default_color = {0, 0, 1, 0.5}
local brush_color = {1, 1, 1, 0.5}
local grid_size
local grid_row
local grid_col
local grid = {}
local total_width
local total_height

local function create_grid(size, row, col)
    grid_size = size
    grid_row = row
    grid_col = col
    total_width = size * col
    total_height = size * row
    for i = 1, row do
        local temp_row = {}
        local posz = 0.5 * size - total_width * 0.5 + (i - 1) * size
        for j = 1, col do
            local posx = 0.5 * size - total_height * 0.5 + (j  - 1) * size
            local tile_eid = computil.create_prim_plane_entity({t = {posx, 0, posz, 1}, s = {size * 0.95, 0, size * 0.95, 0}},
		                "/pkg/ant.resources/materials/singlecolor_translucent_nocull.material", "grid")
	        ies.set_state(tile_eid, "auxgeom", true)
	        imaterial.set_property(tile_eid, "u_color", default_color)
            temp_row[#temp_row + 1] = {eid = tile_eid, color = default_color}
        end
        grid[#grid + 1] = temp_row
    end
end

function brush_sys:init(size, row, col)
    
end

local function get_row_col(pos)
    local min_x, min_y = -0.5 * total_width, -0.5 * total_height
    local max_x, max_y = 0.5 * total_width, 0.5 * total_height
    if pos[1] < min_x or pos[1] > max_x or pos[3] < min_y or pos[3] > max_y then
        return nil, nil
    else
        return math.floor((pos[3] - min_y) / grid_size) + 1, math.floor((pos[1] - min_x) / grid_size) + 1
    end
end

local function on_row_col_select(row, col)
    if not row or not col then return end
    imaterial.set_property(grid[row][col].eid, "u_color", brush_color)
end

local mouse_down = world:sub {"mousedown"}
local event_gridmesh = world:sub {"GridMesh"}

function brush_sys:handle_event()
    for _, what, p1, p2, p3, p4 in event_gridmesh:unpack() do
        if what == "create" then
            create_grid(p1, p2, p3)
        elseif what == "brushcolor" then
            brush_color = {p1, p2, p3, p4}
        end
    end

    if not grid then return end
    for _, what, sx, sy in mouse_down:unpack() do
		if what == "LEFT" then
            local hitpos = utils.ray_hit_plane(iom.ray(camera_mgr.main_camera, {sx, sy}), {dir = {0,1,0}, pos = {0,0,0}})
            if hitpos then
                on_row_col_select(get_row_col(math3d.totable(hitpos)))
            end
        end
    end
end

function brush_sys:post_init()

end