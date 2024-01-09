local ecs   = ...
local world = ecs.world
local w     = world.w

local iplane_terrain  = {}
local renderpkg = import_package "ant.render"
local layoutmgr = renderpkg.layoutmgr
local bgfx      = require "bgfx"
local irender       = ecs.require "ant.render|render_system.render"

local DEFAULT_TERRAIN_RENDER_LAYER <const> = "opacity"
local DEFAULT_TILE_SIZE <const> = 10
local DEFAULT_TERRAIN_CHUNK_SIZE <const> = DEFAULT_TILE_SIZE * 32
local DEFAULT_BORDER_CHUNK_SIZE <const> = DEFAULT_TILE_SIZE * 16

local COLOR_TEX_SIZE <const> = 4
local ALPHA_TEX_SIZE <const> = 1
local TERRAIN_MESH, BORDER_MESH
local pt_sys    = ecs.system 'plane_terrain_system'

--[[
    v1---v3
    |    |
    v0---v2
]]

local function get_quad_tex(width, height)
    return {
    {0, height},                  -- quad v0
    {0, 0},                       -- quad v1
    {width, height},              -- quad v2
    {width, 0},                   -- quad v3
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
            handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(vb), vblayout.handle),  --
        },
        ib = {
            start = 0,
            num = numi,
            handle = ib_handle,
        }
    }
end

local function create_border_mesh()
    assert(BORDER_MESH == nil)

    local function get_border_vb(vbfmt)
        local ox, oz, nx, nz = 0, 0, 1, 1
        return vbfmt:pack(
            ox, 0, oz, 0, 1,
            ox, 0, nz, 0, 0,
            nx, 0, oz, 1, 1,
            nx, 0, nz, 1, 0
        )  
    end

    local vbfmt = ("fffff"):rep(4)
    local layout_name    = layoutmgr.correct_layout "p3|t20"
    local layout         = layoutmgr.get(layout_name)
    return to_mesh_buffer(get_border_vb(vbfmt), layout, irender.quad_ib())
end

local function create_terrain_mesh()
    assert(TERRAIN_MESH == nil)

    local function get_terrain_vb(color_texcoords, alpha_texcoords, vbfmt)
        local ox, oz, nx, nz = 0, 0, 1, 1
        return vbfmt:pack(
            ox, 0, oz, color_texcoords[1][1], color_texcoords[1][2], alpha_texcoords[1][1], alpha_texcoords[1][2],
            ox, 0, nz, color_texcoords[2][1], color_texcoords[2][2], alpha_texcoords[2][1], alpha_texcoords[2][2],
            nx, 0, oz, color_texcoords[3][1], color_texcoords[3][2], alpha_texcoords[3][1], alpha_texcoords[3][2],
            nx, 0, nz, color_texcoords[4][1], color_texcoords[4][2], alpha_texcoords[4][1], alpha_texcoords[4][2]
        )       
    end

    local color_texcoords = get_quad_tex(COLOR_TEX_SIZE, COLOR_TEX_SIZE)
    local alpha_texcoords = get_quad_tex(ALPHA_TEX_SIZE, ALPHA_TEX_SIZE)
    local vbfmt = ("fffffff"):rep(4)
    local layout_name    = layoutmgr.correct_layout "p3|t40"
    local layout         = layoutmgr.get(layout_name)
    return to_mesh_buffer(get_terrain_vb(color_texcoords, alpha_texcoords, vbfmt), layout, irender.quad_ib())
end

local function create_plane_entity(gid, size, xypos, mesh, material, render_layer)
    local hs = size * 0.5
    return world:create_entity {
        group = gid,
        policy = {
            "ant.render|simplerender",
            "ant.landform|plane_terrain"
        },
        data = {
            scene               = {s = {size, 1, size}, t = {xypos.x, 0, xypos.y}},
            simplemesh          = assert(mesh),
            material            = material,
            visible_state       = "main_view|selectable",
            render_layer        = render_layer,
            bounding            = {
                aabb = {
                    {-hs, 0,   -hs},
                    { hs, 1e-6, hs},
                }
            },
            plane_terrain       = true,
        },
    }
end

local function create_plane_entities(groups, chunksize, mesh, material, render_layer)
    for gid, infos in pairs(groups) do
        --TODO: merge these plane together
        for _, info in ipairs(infos) do
            create_plane_entity(gid, chunksize, info, mesh, material, render_layer)
        end
    end
end

function iplane_terrain.create_plane_terrain(groups, render_layer, terrain_chunk, terrain_material)
    terrain_chunk = terrain_chunk or DEFAULT_TERRAIN_CHUNK_SIZE
    render_layer = render_layer or DEFAULT_TERRAIN_RENDER_LAYER
    create_plane_entities(groups, terrain_chunk, TERRAIN_MESH, terrain_material, render_layer)
end

function iplane_terrain.create_borders(groups, render_layer, border_chunk, border_material)
    border_chunk = border_chunk or DEFAULT_BORDER_CHUNK_SIZE
    render_layer = render_layer or DEFAULT_TERRAIN_RENDER_LAYER

    create_plane_entities(groups, border_chunk, TERRAIN_MESH, border_material, render_layer)
end

local function clear_plane_terrain()
    for e in w:select "plane_terrain eid:in" do
        w:remove(e.eid)
    end
end

iplane_terrain.clear_plane_terrain = clear_plane_terrain

function pt_sys:init()
    TERRAIN_MESH = create_terrain_mesh()
    BORDER_MESH = create_border_mesh()
end

function pt_sys:exit()
    local function destroy_mesh(m)
        assert(m)
        bgfx.destroy(m.vb.handle)
        m.vb.handle = nil
        m = nil
    end
    destroy_mesh(TERRAIN_MESH)
    destroy_mesh(BORDER_MESH)

    clear_plane_terrain()
end

return iplane_terrain
