local ecs   = ...
local world = ecs.world
local w     = world.w

local igrid  = {}
local renderpkg = import_package "ant.render"
local layoutmgr = renderpkg.layoutmgr
local bgfx      = require "bgfx"
local math3d    = require "math3d"
local irender   = ecs.require "ant.render|render_system.render"
local imaterial = ecs.require "ant.asset|material"

local DEFAULT_GRID_MATERIAL <const> = "/pkg/ant.grid/assets/grid.material"
local DEFAULT_GRID_COLOR = math3d.mark(math3d.vector(1.0, 1.0, 1.0, 1.0))
local DEFAULT_GRID_RENDER_LAYER <const> = "translucent"

--[[
    v1---v3
    |    |
    v0---v2
]]

local function get_quad_tex()
    return {
    {0, 1},
    {0, 0},
    {1, 1},
    {1, 0},
}
end

local function to_mesh_buffer(vb, vblayout, ib_handle)
    local numv = 4
    local numi = 6

    return {
        bounding = nil,
        vb = {
            start = 0,
            num = numv,
            handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(vb), vblayout.handle),
        },
        ib = {
            start = 0,
            num = numi,
            handle = ib_handle,
        }
    }
end


local function get_quad_mesh()
    local texcoords = get_quad_tex()
    local vbfmt = ("fffff"):rep(4)
    local layout_name    = layoutmgr.correct_layout "p3|t20"
    local layout         = layoutmgr.get(layout_name)

    local function get_vb()
        local ox, oz, nx, nz = 0, 0, 1, 1
        return vbfmt:pack(
            ox, 0, oz, texcoords[1][1], texcoords[1][2],
            ox, 0, nz, texcoords[2][1], texcoords[2][2],
            nx, 0, oz, texcoords[3][1], texcoords[3][2],
            nx, 0, nz, texcoords[4][1], texcoords[4][2]
        )       
    end

    return to_mesh_buffer(get_vb(), layout, irender.quad_ib())
end

local DEFAULT_GRID_MESH = get_quad_mesh()

local function create_grid_object(grid_params, grid_color, grid_render_layer, grid_srt)

    return world:create_entity {
        policy = {
            "ant.render|simplerender",
        },
        data = {
            scene = grid_srt,
            simplemesh  = DEFAULT_GRID_MESH,
            material    = DEFAULT_GRID_MATERIAL,
            visible_state = "main_view|selectable",
            render_layer = grid_render_layer,
            on_ready = function (e)
                imaterial.set_property(e, "u_grid_params", math3d.ref(grid_params))
                imaterial.set_property(e, "u_basecolor_factor", math3d.ref(grid_color))
            end
        },
    }
end

local function get_grid_params(grid_width, grid_height, line_scale_x, line_scale_z, srt)
    local sx, sz = srt[1], srt[3]
    return math3d.mark(math3d.vector(grid_width / sx, grid_height / sz, line_scale_x, line_scale_z))
end

function igrid.create_grid(grid_width, grid_height, line_scale_x, line_scale_z, srt, color, render_layer)
    local scale = srt.s and math3d.tovalue(srt.s) or {1.0, 1.0, 1.0}
    local grid_render_layer = render_layer and render_layer or DEFAULT_GRID_RENDER_LAYER
    local grid_color = color and math3d.mark(math3d.vector(color)) or math3d.ref(DEFAULT_GRID_COLOR)
    local grid_params = get_grid_params(grid_width, grid_height, line_scale_x, line_scale_z, scale)
    return create_grid_object(grid_params, grid_color, grid_render_layer, srt)
end

return igrid
