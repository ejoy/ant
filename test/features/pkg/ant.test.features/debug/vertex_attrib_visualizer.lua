local ecs   = ...
local world = ecs.world
local w     = world.w

local bgfx = require "bgfx"
local math3d = require "math3d"
local layoutmgr = import_package "ant.render".layoutmgr

local ivav = {}
local imaterial = ecs.require "ant.asset|material"

local function find_stream(vb, what)
    for i=1, #vb do
        local v = vb[i]
        local s = 1
        for dn in v.declname:gmatch "[^|]+" do
            local stride = layoutmgr.layout_stride(dn)
            if dn:match(what) then
                return {
                    s = v, 
                    start = s,
                    num = stride,
                    declname = dn,
                }
            end
            s = s + stride
        end
    end
end

local function create_line_arrow_mesh(len)
    local head_height<const> = len * 0.08
    local head_len<const> = len * 0.15

    return {
        vb = {
            start = 0,
            num = 4,
            handle = bgfx.create_vertex_buffer(bgfx.memory_buffer("fff", {
                0.0, 0.0, 0.0,
                0.0, 0.0, len,
                -head_height, 0.0, len - head_len,
                    head_height, 0.0, len - head_len,
            }), layoutmgr.get "p3".handle),
        },
        ib = {
            start = 0,
            num = 6,    -- 3 line
            handle = bgfx.create_index_buffer(bgfx.memory_buffer("w", {
                0, 1, 2, 1, 3, 1
            }))
        }
    }
end

local line_arrow_mesh<const> = create_line_arrow_mesh(1.0)

local function create_line_arrow_entity(parent, srt, color)
    return world:create_entity{
        policy = {
            "ant.render|simplerender",
        },
        data = {
            simplemesh = line_arrow_mesh,
            material = "/pkg/ant.resources/materials/line_color.material",
            visible_state = "main_view",
            render_layer = "translucent",
            scene = {s=srt.s, r=srt.r, t=srt.t},
            on_ready = function (e)
                imaterial.set_property(e, "u_color", color)
                ecs.method.set_parent(e.id, parent)
            end
        }
    }
end

local normal_color = math3d.ref(math3d.vector(0.0, 0.0, 1.0, 1.0))

function ivav.display_normal(e)
    local m = e.mesh
    if m == nil then
        return
    end
    local vb = m.vb
    local ns = find_stream(vb, "n[1-4]")
    local ps = find_stream(vb, "p[1-4]")

    assert(ns.declname:sub(6, 6) == 'f')
    assert(ps.declname:sub(6, 6) == 'f')

    local function read_vertex(s, iv, stride)
        local memory = s.memory
        assert(#memory == 3)

        local data = memory[1]
        local startbyte, sizebytes = memory[2], memory[3]

        local offset = (iv-1)*stride+startbyte
        assert(offset <= sizebytes)

        return data:sub(offset, offset+stride-1)
    end
    local ps_stride = layoutmgr.layout_stride(ps.s.declname)
    local ns_stride = layoutmgr.layout_stride(ns.s.declname)

    local function read_attrib(vdata, s, n)
        return vdata:sub(s, s+n-1)
    end
    for i=1, math.min(100, vb.num) do
        local p = read_attrib(read_vertex(ps.s, i, ps_stride), ps.start, ps.num)
        local n = read_attrib(read_vertex(ns.s, i, ns_stride), ns.start, ns.num)

        local pos
        do
            local x, y, z = ("fff"):unpack(p)
            pos = math3d.vector(x, y, z, 1.0)
        end
        
        local normal
        do
            local x, y, z = ("fff"):unpack(n)
            normal = math3d.normalize(math3d.vector(x, y, z, 0.0))
        end

        create_line_arrow_entity(e.id, {
            t = pos,
            r = math3d.torotation(normal),
        }, normal_color)
    end
end

return ivav
