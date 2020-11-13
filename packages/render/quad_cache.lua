local ecs = ...
local world = ecs.world

local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr

local irender = world:interface "ant.render|irender"

local bgfx = require "bgfx"
local math3d = require "math3d"

local iqc = ecs.interface "iquadcache"

local vb, ib
local vb_num, ib_num

local default_quad<const> = {
    --pos.xyz, normal.xyz, texcoord.uv, color.dword
    -0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0xffffffff,
    -0.5,  0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0xffffffff,
     0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0xffffffff,
     0.5,  0.5, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0xffffffff,
}

local quad_elemnum = #default_quad

local layout_desc = declmgr.correct_layout "p3|n3|t2|c40niu"
local vertex_layout = declmgr.get(layout_desc)
local vertex_format = declmgr.vertex_desc_str(layout_desc)
local vertex_elemnum = quad_elemnum / 4

function iqc.init(numquad)
    ib_num = numquad * 2 * 3
    if numquad > irender.quad_ib_num() then
        error(("require quad number is too large:%d, max: %d"):format(numquad, irender.quad_ib_num()))
    end
    ib = {
        handle = irender.quad_ib()
    }

    vb_num = numquad * 4
    local vb_size = vertex_layout.stride * vb_num
    vb = {
        handles = {
            bgfx.create_dynamic_vertex_buffer(vb_size, vertex_layout.handle),
        }
    }
end

local vbcache = {n=0}

function iqc.quad_num()
    return vbcache.n / quad_elemnum
end

function iqc.alloc_quad_buffer(numquad)
    local start = vbcache.n
    for ii=1, numquad do
        table.move(default_quad, 1, quad_elemnum, vbcache.n+1, vbcache)
        vbcache.n = vbcache.n + quad_elemnum
    end

    return {
        start = start / vertex_elemnum,
        num = numquad * 4,
        handles = vb.handles,
    }, {
        start = 0, --quadoffset * 2 * 3,
        num = numquad * 2 * 3,
        handle = ib.handle,
    }
end

local function check_vertex_index(vertexidx)
    local numv = (vbcache.n / vertex_elemnum)
    if vertexidx <= 0  or vertexidx > numv then
        error(("invalid vertex index: %d, %d"):format(vertexidx, numv))
    end
end

local function elem_offset(vertexidx)
    return (vertexidx-1) * vertex_elemnum
end

function iqc.vertex_pos(vertexidx)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    return vbcache[offset+1], vbcache[offset+2], vbcache[offset+3]
end

function iqc.vertex_normal(vertexidx)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    return vbcache[offset+4], vbcache[offset+5], vbcache[offset+6]
end

function iqc.vertex_texcoord(vertexidx)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    return vbcache[offset+7], vbcache[offset+8]
end

function iqc.vertex_color(vertexidx)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    return vbcache[offset+9]
end

function  iqc.set_vertex_pos(vertexidx, x, y, z)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    vbcache[offset+1], vbcache[offset+2], vbcache[offset+3] = x, y, z
end

function  iqc.set_vertex_normal(vertexidx, x, y, z)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    vbcache[offset+4], vbcache[offset+5], vbcache[offset+6] = x, y, z
end

function iqc.set_vertex_texcoord(vertexidx, u, v)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    vbcache[offset+7], vbcache[vertexidx+8]= u, v
end

function iqc.set_vertex_color(vertexidx, color)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    vbcache[offset+9] = color
end

local patchs = {}

function iqc.update()
    --TODO: we need to combine patchs
    for _, p in ipairs(patchs) do
        local offset, num = p[1], p[2]
        local maxquad = vbcache.n / quad_elemnum
        if (offset + num) > maxquad then
            error(("invalid patch:(%d, %d), max quad: %d"):format(offset, num, vbcache.n / quad_elemnum))
        end

        local startv = offset * 4
        local numv = num * 4
        bgfx.update(vb.handles[1], startv, bgfx.memory_buffer(vertex_format, vbcache, startv+1, numv))
    end
    patchs = {}
end

function iqc.submit_patch(start, num)
    patchs[#patchs+1] = {start, num}
end

local qc_sys = ecs.system "quadcache_system"
function qc_sys:init()
    iqc.init(256)
end