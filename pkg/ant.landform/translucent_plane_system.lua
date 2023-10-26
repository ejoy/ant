local ecs       = ...
local world     = ecs.world
local w         = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local irender       = ecs.require "ant.render|render_system.render"
local renderpkg = import_package "ant.render"
local layoutmgr = renderpkg.layoutmgr
local layout    = layoutmgr.get "p3|t20"
local imaterial = ecs.require "ant.asset|material"
local tp_sys  = ecs.system 'translucent_plane_system'
local translucent_plane_material

function tp_sys:init_world()
    translucent_plane_material = "/pkg/ant.landform/assets/materials/translucent_plane.material"
end

local ENTITIES = {}

local MAX_EDGE<const> = 9

local MESH_CACHE = setmetatable({}, {__index=function (t, k) local tt = {}; t[k] = tt; return tt end})

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

local VBFMT<const> = ("fffff"):rep(4)

local function get_mesh(width, height)

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
    return to_mesh_buffer(get_vb(), irender.quad_ib())
end

for i = 1, MAX_EDGE do
    for j = 1, MAX_EDGE do
        MESH_CACHE[i][j] = get_mesh(i, j)
    end
end

local itp = {}

local function create_tp_entity(info, render_layer, tile_size)
    local gid, color = info.gid, info.color
    local meshidx = {info.w / tile_size, info.h / tile_size}
    local mesh = MESH_CACHE[meshidx[1]][meshidx[2]]

    ENTITIES[#ENTITIES+1] = world:create_entity {
        group = gid,
        policy = {
            "ant.render|simplerender",
        },
        data = {
            scene = {s = {info.w, 1, info.h}, t = {info.x, 0, info.y}},
            simplemesh  = mesh,
            material    = translucent_plane_material,
            visible_state = "main_view|selectable",
            render_layer = render_layer,
            on_ready = function (e)
                imaterial.set_property(e, "u_basecolor_factor", math3d.vector(color[1], color[2], color[3], color[4]))
            end,
        },
    }
end

function itp.update_tp(infos, render_layer, tile_size)
    for _, info in ipairs(infos) do
        create_tp_entity(info, render_layer, tile_size) 
    end
end

function itp.clear_tp()
    for _, eid in ipairs(ENTITIES) do
        w:remove(eid)
    end
end

return itp
