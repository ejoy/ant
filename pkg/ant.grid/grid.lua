local ecs   = ...
local world = ecs.world
local w     = world.w

local igrid  = {}
local grid_sys   = ecs.system "grid_system"
local renderpkg = import_package "ant.render"
local layoutmgr = renderpkg.layoutmgr
local bgfx      = require "bgfx"
local math3d    = require "math3d"
local irender   = ecs.require "ant.render|render_system.render"
local imaterial = ecs.require "ant.asset|material"

local DEFAULT_GRID_MATERIAL <const> = "/pkg/ant.grid/assets/grid.material"
local DEFAULT_GRID_COLOR = math3d.ref(math3d.vector(1.0, 1.0, 1.0, 1.0))
local DEFAULT_GRID_RENDER_LAYER <const> = "translucent"

local DEFAULT_GRID_MESH

local function destroy_handle(h)
    if h then
        bgfx.destroy(h)
    end
end

function grid_sys:exit()
    if DEFAULT_GRID_MESH and DEFAULT_GRID_MESH.vb.handle then
        DEFAULT_GRID_MESH.vb.handle = destroy_handle(DEFAULT_GRID_MESH.vb.handle)
    end
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
    local vbfmt = ("fffff"):rep(4)
    local layout_name    = layoutmgr.correct_layout "p3|t20"
    local layout         = layoutmgr.get(layout_name)

    local function get_vb()
        local ox, oz, nx, nz = 0, 0, 1, 1
        return vbfmt:pack(
            ox, 0, oz, 0, 1,
            ox, 0, nz, 0, 0,
            nx, 0, oz, 1, 1,
            nx, 0, nz, 1, 0
        )       
    end
    DEFAULT_GRID_MESH = to_mesh_buffer(get_vb(), layout, irender.quad_ib())
    return DEFAULT_GRID_MESH
end

local function create_grid_entity(grid_params, grid_color, grid_render_layer, grid_srt)
    return world:create_entity {
        policy = {
            "ant.render|simplerender",
        },
        data = {
            scene = grid_srt,
            simplemesh  = DEFAULT_GRID_MESH and DEFAULT_GRID_MESH or get_quad_mesh(),
            material    = DEFAULT_GRID_MATERIAL,
            visible_state = "main_view|selectable",
            render_layer = grid_render_layer,
            on_ready = function (e)
                imaterial.set_property(e, "u_grid_params", grid_params)
                imaterial.set_property(e, "u_basecolor_factor", grid_color)
            end
        },
    }
end

local function get_grid_scale(srt)
    if srt and srt.s then
        assert(type(srt.s):match "userdata", "srt type should be math3d id!\n")
        return math3d.index(srt.s, 1, 3)
    else
        return 1.0, 1.0
    end
end

local function get_grid_params(grid_width, grid_height, line_scale_x, line_scale_z, scale_width, scale_height)
    local function normalize_grid_size(gw, gh, sw, wh)
        return gw / sw, gh / wh
    end
    grid_width, grid_height = normalize_grid_size(grid_width, grid_height, scale_width, scale_height)
    return math3d.vector(grid_width, grid_height, line_scale_x, line_scale_z)
end

function igrid.create_grid_entity(grid_width, grid_height, line_scale_x, line_scale_z, srt, color, render_layer)
    local grid_render_layer = render_layer and render_layer or DEFAULT_GRID_RENDER_LAYER
    local grid_color = color and math3d.vector(color) or DEFAULT_GRID_COLOR

    local scale_width, scale_height = get_grid_scale(srt)
    local grid_params = get_grid_params(grid_width, grid_height, line_scale_x, line_scale_z, scale_width, scale_height)
    return create_grid_entity(grid_params, grid_color, grid_render_layer, srt)
end

return igrid
