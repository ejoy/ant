local ecs = ...
local world = ecs.world
local utils = require "mathutils"(world)
local camera_mgr = require "camera_manager"(world)
local math3d = require "math3d"
local iom = world:interface "ant.objcontroller|obj_motion"
local iss = world:interface "ant.scene|iscenespace"
local computil = world:interface "ant.render|entity"

local brush_sys = ecs.system "grid_brush_system"

local mouse_down = world:sub {"mousedown"}

local grid_size = 0.2
local grid_row = 10
local grid_col = 10
local grid = {}
local default_color = {0, 0, 1, 0.5}
local brush_color
function brush_sys:init()
    -- local width = grid_size * grid_col
    -- local height = grid_size * grid_row
    
    -- for i = 1, grid_row do
    --     local row = {}
    --     local posz = 0.5 * grid_size - width * 0.5 + (i - 1) * grid_size
    --     for j = 1, grid_col do
    --         local posx = 0.5 * grid_size - width * 0.5 + (j  - 1) * grid_size
    --         local tile_eid = computil.create_prim_plane_entity({t = {posx, 0, posz, 1}, s = {grid_size * 0.95, 0, grid_size * 0.95, 0}},
	-- 	                "/pkg/ant.resources/materials/singlecolor_translucent_nocull.material", "grid")
	--         ies.set_state(tile_eid, "auxgeom", true)
	--         imaterial.set_property(tile_eid, "u_color", default_color)
    --         row[#row + 1] = {eid = tile_eid, color = default_color}
    --     end
    --     grid[#grid + 1] = row
    -- end
end

function brush_sys:data_changed()
    --utils.ray_hit_plane(iom.ray(camera_mgr.main_camera, screen_pos), {dir = {0,1,0}, pos = {0,0,0}})
end

function brush_sys:post_init()

end