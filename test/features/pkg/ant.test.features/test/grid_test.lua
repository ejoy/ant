local ecs   = ...
local world = ecs.world
local w     = world.w

local common = ecs.require "common"
local math3d = require "math3d"
local igrid = ecs.require "ant.grid|grid"

local util = ecs.require "util"
local PC = util.proxy_creator()

local grid_sys = common.test_system "grid"
local function create_grid_entity()
    local grid_width, grid_height = 100, 100 -- [1, ...] 100 x 100
    local line_width_scale, line_height_scale = 0.1, 0.1 -- [0, 1] 0 empty 1 filled
    local srt = {
        s = math3d.vector(100, 1, 100) -- whole grid scale, grid scale x / grid_width = per grid width, grid scale z / grid_height = per grid height
    }
    local color = {1.0, 0.0, 0.0, 1.0} -- default {1.0, 1.0, 1.0, 1.0}
    local render_layer = "translucent" -- default "translucent"
    PC:add_entity(igrid.create_grid_entity(grid_width, grid_height, line_width_scale, line_height_scale, srt, color, render_layer))
end

function grid_sys:init_world()
    create_grid_entity()
end

function grid_sys:exit()
    PC:clear()
end
