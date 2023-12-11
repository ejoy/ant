local ecs       = ...
local world     = ecs.world
local w         = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local irender   = ecs.require "ant.render|render_system.render"
local renderpkg = import_package "ant.render"
local layoutmgr = renderpkg.layoutmgr
local layout    = layoutmgr.get "p3|t20"
local imaterial = ecs.require "ant.asset|material"
local tp_sys    = ecs.system 'translucent_plane_system'

local DEFAULT_TP_RENDER_LAYER <const> = "translucent"
local DEFAULT_TILE_SIZE <const> = 10

local ENTITIES = {}

local MAX_EDGE<const> = 9

local MESH_CACHE = setmetatable({}, {__index=function (t, k) local tt = {}; t[k] = tt; return tt end})

local VBFMT<const> = ("fffff"):rep(4)

local function get_mesh(width, height)
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

    local function to_mesh_buffer(vb, ib_handle)
        local numv = 4
        local numi = 6
    
        return {
            bounding = nil,
            vb = {
                start = 0,
                num = numv,
                handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(vb), layout.handle),
            },
            ib = {
                start = 0,
                num = numi,
                handle = ib_handle,
            }
        }
    end

    local function get_vb()
        local texcoords = get_quad_tex(width / MAX_EDGE, height / MAX_EDGE)
        local ox, oz, nx, nz = 0, 0, 1, 1
        return VBFMT:pack(
            ox, 0, oz, texcoords[1][1], texcoords[1][2],
            ox, 0, nz, texcoords[2][1], texcoords[2][2],
            nx, 0, oz, texcoords[3][1], texcoords[3][2],
            nx, 0, nz, texcoords[4][1], texcoords[4][2]
        )       
    end
    MESH_CACHE[width][height] = to_mesh_buffer(get_vb(), irender.quad_ib())
    return MESH_CACHE[width][height]
end

local function create_tp_entity(info, render_layer, tile_size, material)
    local gid, color = info.gid, info.color
    local mi, mj = info.w / tile_size, info.h / tile_size
    local mesh = MESH_CACHE[mi][mj] and MESH_CACHE[mi][mj] or get_mesh(mi, mj)

    ENTITIES[#ENTITIES+1] = world:create_entity {
        group = gid,
        policy = {
            "ant.render|simplerender",
        },
        data = {
            scene = {s = {info.w, 1, info.h}, t = {info.x, 0, info.y}},
            simplemesh  = mesh,
            material    = material,
            visible_state = "main_view|selectable",
            render_layer = render_layer,
            on_ready = function (e)
                imaterial.set_property(e, "u_basecolor_factor", math3d.vector(color))
            end,
        },
    }
end

local function destroy_handle(h)
    if h then
        bgfx.destroy(h)
    end
end

function tp_sys:exit()
    for i = 1, MAX_EDGE do
        for j = 1, MAX_EDGE do
            if MESH_CACHE[i][j] and MESH_CACHE[i][j].vb.handle then
                MESH_CACHE[i][j].vb.handle= destroy_handle(MESH_CACHE[i][j].vb.handle)
            end
        end
    end    
end

local itp = {}

function itp.update_tp(infos, render_layer, tile_size, material)
    local tp_render_layer = render_layer and render_layer or DEFAULT_TP_RENDER_LAYER
    local tp_tile_size    = tile_size and tile_size or DEFAULT_TILE_SIZE
    for _, info in ipairs(infos) do
        create_tp_entity(info, tp_render_layer, tp_tile_size, material) 
    end
end

function itp.clear_tp()
    for _, eid in ipairs(ENTITIES) do
        w:remove(eid)
    end
    ENTITIES = {}
end

return itp
