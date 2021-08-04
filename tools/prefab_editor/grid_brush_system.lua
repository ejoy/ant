local ecs = ...
local world = ecs.world
local math3d = require "math3d"
local iss = world:interface "ant.scene|iscenespace"
local computil = world:interface "ant.render|entity"

local brush_sys = ecs.system "grid_brush_system"

local grid_size = 0.2
local grid_row = 10
local grid_col = 10
local grid = {}
local default_color = {0, 0, 1, 0.5}
function brush_sys:init()
    -- for i = 1, grid_row do
    --     local row = {}
    --     for j = 1, grid_col do
    --         local tile_eid = computil.create_prim_plane_entity({t = {gizmo_const.MOVE_PLANE_OFFSET, 0, gizmo_const.MOVE_PLANE_OFFSET, 1}, s = {gizmo_const.MOVE_PLANE_SCALE, 1, gizmo_const.MOVE_PLANE_SCALE, 0}},
	-- 	"/pkg/ant.resources/materials/singlecolor_translucent_nocull.material",
	-- 	"plane_zx")
	--         ies.set_state(tile_eid, "auxgeom", true)
	--         imaterial.set_property(tile_eid, "u_color", gizmo.tzx.color)
    --         row[#row + 1] = 
    --     end
    --     grid[#grid + 1] = row
    -- end
end

function brush_sys:data_changed()

end

function brush_sys:post_init()

end