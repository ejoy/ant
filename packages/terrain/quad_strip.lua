local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant
local math3d    = require "math3d"
local bgfx      = require "bgfx"

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr
local layoutfmt<const> = declmgr.correct_layout "p3|c40niu|t20"
local vertexfmt = declmgr.vertex_desc_str(layoutfmt)
local layout    = declmgr.get(layoutfmt)
local stride<const> = layout.stride

local irender   = ecs.import.interface "ant.render|irender"
local iql       = ecs.import.interface "ant.render|ipolyline"
local imesh     = ecs.import.interface "ant.asset|imesh"
local imaterial = ecs.import.interface "ant.asset|imaterial"

local function add_quad(p0, p1, normal, ww, offset, clr, vertices)
    local d = math3d.sub(p1, p0)
    local x = math3d.normalize(math3d.cross(normal, d))
    local pp = {
        math3d.muladd(x, -ww, p0), 0.0, 0.0,
        math3d.muladd(x, -ww, p1), 0.0, 1.0,
        math3d.muladd(x,  ww, p1), 1.0, 1.0,
        math3d.muladd(x,  ww, p0), 1.0, 0.0,
    }

    for i=1, #pp, 3 do
        local p, u, v = pp[i], pp[i+1], pp[i+2]
        local px, py, pz = math3d.index(p, 1, 2, 3)
        vertices[offset] = ('fffIff'):pack(
                    px, py, pz,
                    clr, u, v)
        offset = offset + stride
    end

    return offset
end


local qs_sys        = ecs.system "quad_strip_system"

function qs_sys:entity_init()
    for e in w:select "INIT quad_strip:in uv_motion:in material:in reference:in" do
        local qs = e.quad_strip
        local uvm = e.uv_motion
        local speed = uvm.speed
        local tile = uvm.tile
        local quadstrip_mesh = iql.create_linestrip_mesh(qs.points, qs.width, qs.color, uvm.rotation, qs.loop)
        local le = ecs.create_entity{
            policy = {
                "ant.render|simplerender",
                "ant.general|name",
            },
            data = {
                simplemesh = quadstrip_mesh,
                material = e.material,
                filter_state = "main_view",
                scene = {srt={}},
                name = "polyline",
                reference = true,
                on_ready = function (le)
                    imaterial.set_property(le, "u_line_info", {qs.width, 0.0, 0.0, 0.0})
                    imaterial.set_property(le, "u_color", qs.color)
                    imaterial.set_property(le, "u_uvmotion", {speed[1], speed[2], tile[1], tile[2]})
                end,
            }
        }

        ecs.method.set_parent(le, e.reference)
    end
end