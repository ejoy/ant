local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr

local bgfx = require "bgfx"
local math3d = require "math3d"

local qc = {} qc.__index = qc

local vb, ib
local vb_num, ib_num
local function create_static_quad_ib(num_quad)
    local b = {}
    for ii=1, num_quad do
        local offset = (ii-1) * 4
        b[#b+1] = offset + 0
        b[#b+1] = offset + 1
        b[#b+1] = offset + 2

        b[#b+1] = offset + 1
        b[#b+1] = offset + 3
        b[#b+1] = offset + 2
    end

    return bgfx.create_index_buffer(bgfx.memory_buffer("w", b))
end

local default_quad<const> = {
    --pos.xyz, normal.xyz, texcoord.uv, color.dword
    -0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0xffffffff,
    -0.5,  0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0xffffffff,
     0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0xffffffff,
     0.5,  0.5, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0xffffffff,
}

local layout_desc = declmgr.correct_layout "p3|n3|t2|c40niu"
local vertex_layout = declmgr.get(layout_desc)
local vertex_format = declmgr.vertex_desc_str(layout_desc)
local vertex_elemnum = #default_quad / 4

local function del_buffer()
    if ib then
        bgfx.destory(ib.handle)
        ib = nil
    end
    if vb then
       bgfx.destory(bgfx.vb.handles[1])
       vb = nil
    end

    ib_num, vb_num = nil, nil
end

function qc.init(numquad)
    del_buffer()
    ib_num = numquad * 2 * 3
    ib = {
        handle = create_static_quad_ib(numquad)
    }

    vb_num = numquad * 4
    local vb_size = vertex_layout.stride * vb_num
    vb = {
        handles = {
            bgfx.create_dynamic_vertex_buffer(vb_size, vertex_layout.handle),
        }
    }
end

qc.clear = del_buffer

local vbcache = {n=0}

function qc.quad_num()
    return vbcache.n / #default_quad
end

local quad_srt = {}
local function add_srt()
    return {
        s = math3d.ref(math3d.vector(1.0, 1.0, 1.0)),
        r = math3d.ref(math3d.quaternion(0.0, 0.0, 0.0, 1.0)),
        t = math3d.ref(math3d.vector(0.0, 0.0, 0.0, 1.0)),
    }
end

function qc.alloc_quad_buffer(numquad)
    local start = vbcache.n
    local def_elemnum = #default_quad
    for ii=1, numquad do
        table.move(default_quad, 1, def_elemnum, vbcache.n+1, vbcache)
        vbcache.n = vbcache.n + def_elemnum

        quad_srt[#quad_srt+1] = add_srt()
    end

    return {
        start = start / vertex_elemnum,
        num = vbcache.n / vertex_elemnum,
        handles = vb.handles,
    }, {
        start = 0,
        num = numquad * 2,
        handle = ib.handle,
    }
end

local function check_vertex_index(vertexidx)
    if vertexidx == 0 or vertexidx > vbcache.n then
        error(("invalid vertex index: %d, %d"):format(vertexidx, vbcache.n))
    end
end

local function elem_offset(vertexidx)
    return (vertexidx-1) * vertex_elemnum
end

function qc.vertex_pos(vertexidx)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    return vbcache[offset+1], vbcache[offset+2], vbcache[vertexidx+3]
end

function qc.vertex_normal(vertexidx)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    return vbcache[offset+4], vbcache[offset+5], vbcache[offset+6]
end

function qc.vertex_texcoord(vertexidx)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    return vbcache[offset+7], vbcache[offset+8]
end

function  qc.set_vertex_pos(vertexidx, x, y, z)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    vbcache[offset+1], vbcache[offset+2], vbcache[offset+3] = x, y, z
end

function  qc.set_vertex_normal(vertexidx, x, y, z)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    vbcache[offset+4], vbcache[offset+5], vbcache[offset+6] = x, y, z
end

function qc.set_vertex_texcoord(vertexidx, u, v)
    check_vertex_index(vertexidx)
    local offset = elem_offset(vertexidx)
    vbcache[offset+7], vbcache[vertexidx+8]= u, v
end

function qc.set_quad_orientation(quadidx, q)
    quad_srt[quadidx].r.q = q
end

function qc.set_quad_scale(quadidx, s)
    if type(s) == "number" then
        quad_srt[quadidx].s.v = {s, s, s}
    else
        quad_srt[quadidx].s.v = s
    end
end

function qc.set_quad_translate(quadidx, t)
    quad_srt[quadidx].t.v = t
end

function qc.quad_srt(quadidx)
    return quad_srt[quadidx]
end

function qc.set_quad_srt(quadidx, s, r, t)
    local srt = quad_srt[quadidx]
    srt.s, srt.r, srt.t = s, r, t
end

local function update_quad_transform()
    local numquad = qc.quad_num()

    for ii=1, numquad do
        local m = math3d.matrix(quad_srt[ii])
        local offset_vertex = (ii-1) * 4
        for jj=1, 4 do
            local vertexidx = offset_vertex + jj

            local offset = (jj-1) * vertex_elemnum
            local px, py, pz = default_quad[offset+1], default_quad[offset+2], default_quad[offset+3]
            local nx, ny, nz = default_quad[offset+4], default_quad[offset+5], default_quad[offset+6]

            local np = math3d.tovalue(math3d.transform(m, math3d.vector(px, py, pz), 1))
            local nn = math3d.tovalue(math3d.transform(m, math3d.vector(nx, ny, nz), 0))

            qc.set_vertex_pos(vertexidx, np[1], np[2], np[3])
            qc.set_vertex_normal(vertexidx, nn[1], nn[2], nn[3])
        end
    end

end

function qc.update()
    update_quad_transform()
    bgfx.update(vb.handles[1], 0, bgfx.memory_buffer(vertex_format, vbcache, 1, vbcache.n))
end

return qc