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
local imesh     = ecs.import.interface "ant.asset|imesh"

local function add_quad(p0, p1, normal, ww, offset, clr, vertices)
    local d = math3d.sub(p1, p0)
    local x = math3d.normalize(math3d.cross(normal, d))
    local pp = {
        math3d.muladd(x,  ww, p0), 0.0, 0.0,
        math3d.muladd(x,  ww, p1), 0.0, 1.0,
        math3d.muladd(x, -ww, p1), 1.0, 1.0,
        math3d.muladd(x, -ww, p0), 1.0, 0.0,
    }

    for i=1, #pp do
        local p = pp[i]
        vertices[offset] = vertexfmt:pack(
                    math3d.index(p[1], 1, 2, 3),
                    clr, p[2], p[3])
        offset = offset + stride
    end

    return offset
end


local qs_sys        = ecs.system "quad_strip_system"
function qs_sys:component_init()
    -- for te in w:select "INIT shape_terrain:in reference:in" do
    --     local points = {}

    --     ecs.create_entity {
    --         policy = {
    --             "ant.render|simplerender",
    --             "ant.render|uv_motion",
    --             "ant.terrain|quad_strip", --in terrain package?
    --             "ant.general|name",
    --         },
    --         data = {
    --             quad_strip = {
    --                 points = points,
    --             },
    --             uv_motion = {
    --                 direction = "forward",
    --                 speed     = 0.1*st.unit,
    --             },
    --             simplemesh = true,
    --             material = "/",
    --             filter_state = "main_view",
    --             scene = {
    --                 srt = {}
    --             }
    --         }
    --     }
    -- end

    for ie in w:select "INIT quad_strip:in simplemesh:out" do
        local qs = ie.quad_strip
        local points = qs.points
        local width = qs.width
        local hw = width*0.5
        local normal = qs.normal or mc.YAXIS

        local numquad = #points-1
        local numv = numquad * 4
        local vertices = bgfx.memory(numv*stride)
        local offset = 0
        local clr = qs.color
        for i=1, numquad do
            local p0 = points[i]
            local p1 = points[i+1]
            offset = add_quad(p0, p1, normal, hw, offset, clr, vertices)
        end

        local numi = numquad*6

        assert(irender.quad_ib_num() > numi)

        ie.simplemesh = imesh.init_mesh{
            vb = {
                start = 0,
                num = #vertices // 6,
                {
                    handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(vertices), layout.handle),
                }
            },
            ib = {
                start = 0,
                num = numi,
                handle = irender.quad_ib(),
            }
        }
    end
end