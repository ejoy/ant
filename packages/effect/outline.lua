local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr

local imesh = world:interface "ant.asset|imesh"

local ot = ecs.transform "outline_transform"
function ot.process_entity(e)
    e._outline = {}
    for k, v in pairs(e.outline) do
        e._outline[k] = v
    end
end

local cof = ecs.transform "create_outline_prefab"
function cof.process_prefab(e)
    e._outline_prefab = {}
end

local function create_buffer_with_merge_normal(buf, start, num)
	local function get_offsets(declname)
        local offset = 0
        local offsets, orders = {}, {}
        for w in declname:gmatch "%w+" do
            local n = w:sub(1, 1)
            assert('0' == w:sub(3, 3))
            offsets[n] = {offset, w, declmgr.elem_size(w), #orders+1}
            offset = offset + declmgr.elem_size(w)
            orders[#orders+1] = n
        end
        return offsets, orders, declmgr.layout_stride(declname)
    end

    local offsets, orders, stride = get_offsets(buf.declname)

    local function create_buffer_reader(declname)
        local c = tonumber(declname:sub(2, 2))
        local t = declname:sub(6, 6)
        
        local fmt = {
            f = "f",
            i = "h",
            u = "B",
            x = "i",
            X = "I",
        }

        local f = fmt[t]:rep(c)
        return function (buf, offset)
            return string.unpack(f, buf, offset)
        end, function (v)
            if type(v) == "table" then
                return string.pack(f, table.unpack(v))
            end 
            return string.pack(f, v)
        end
    end

    local reader, writer = create_buffer_reader(offsets.n[2])
    local poselemsize = offsets.p[3]
    local posoffset, normaloffset = offsets.p[1]+1, offsets.n[1]+1
    local nbuf = buf.memory[1]
    local cache = {}
    local newbuf = {}

    for iv=start, num-1 do
        local voff = iv * stride + 1
        local v = nbuf:sub(voff, voff+stride-1)
        local p = v:sub(posoffset, posoffset+poselemsize-1)

        local noff = normaloffset + iv * stride
        local nn = math3d.vector(reader(nbuf, noff))
        local c = cache[p]
        if c == nil then
            c = {n=nn, vids={iv+1}}
            cache[p] = c
        else
            c.n = math3d.normalize(math3d.add(nn, c.n));
            c.vids[#c.vids+1] = iv+1;
        end
        local bufidx = #orders * iv
        for i, o in ipairs(orders) do
            local e = offsets[o]
            local off, name, size = e[1], e[2], e[3]
            newbuf[bufidx+i] = name:sub(1, 1) == 'n' and "" or v:sub(off+1, off+size)
        end
    end

    local nidx = offsets.n[4]
    for _, v in pairs(cache) do
        local n = writer(math3d.tovalue(v.n))
        local vids = v.vids
        for _, vidx in ipairs(vids) do
            local idx = (vidx-1) * #orders + nidx
            newbuf[idx] = n
        end
    end

    local bindata = table.concat(newbuf, "")
    return {
        declname = buf.declname,
        memory = {bindata, 1, #bindata},
    }
end

local ompt = ecs.transform "outline_mesh_prefab_transform"
function ompt.process_prefab(e)
    local mesh = e.mesh
    if mesh == nil then
        return
    end

    local vb = mesh.vb
    local outline_vb = imesh.create_vb(create_buffer_with_merge_normal(vb[1], vb.start, vb.num))
    e._outline_prefab.outline_vb = outline_vb
end

local omt = ecs.transform "outline_mesh_transform"
function omt.process_entity(e)
    local mesh = e.mesh
    if mesh == nil then
        return 
    end
    
    local op = e._outline_prefab
    local rc = e._rendercache

    local outline_vb = op.outline_vb

    local handles = {
        outline_vb.handle
    }

    for i=2, #rc.vb.handles do
        handles[#handles+1] = rc.vb.handles[i]
    end

    rc.vb.handles = handles
end

local iol = ecs.interface "ioutline"
function iol.set_outline(eid, l)
    local e = world[eid]
    local ol = e._outline
    if ol then
        e._outline.width = l.width
        e._outline.color = l.color
    end
end

local ms_ol_sys = ecs.system "meshscale_outline_system"
function ms_ol_sys:data_changed()

end