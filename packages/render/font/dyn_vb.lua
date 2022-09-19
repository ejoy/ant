local dyn_vb = {}; dyn_vb.__index = dyn_vb
local declmgr = require "vertexdecl_mgr"
local bgfx = require "bgfx"

local dvbidx_table={}

function dyn_vb:create(maxsize, fmt)
    local d = declmgr.get(fmt)
    local handle = bgfx.create_dynamic_vertex_buffer(maxsize, d.handle)
    return setmetatable({
        data={},
        handle = handle,
        format = fmt,
        stride = d.stride,
    }, dyn_vb)
end

function dyn_vb:destroy()
    if self.handle then
        bgfx.destroy(self.handle)
        self.handle = nil
    end
end

local function numv(m, s)
    local sizebytes = #m
    return sizebytes // s
end

function dyn_vb:add(mem,fontidx_table,fontidx)
    local idx = #self.data+1
    self.data[idx] = mem
    fontidx_table[fontidx]=idx
    dvbidx_table[idx]=fontidx
    local offsetV = self:update(idx, idx)
    local n = numv(mem, self.stride)
    return offsetV-n, n
end

function dyn_vb:remove(fontidx,fontidx_table)
    local offsetV=0
    local dvbidx=fontidx_table[fontidx]
    local s=self.stride
    for i=1,dvbidx-1 do
        local m=self.data[i]
        offsetV=offsetV+numv(m,s)
    end

    for i=dvbidx,#self.data-1 do
        local fidx=dvbidx_table[i+1]
        local m=self.data[i+1]
        fontidx_table[fidx]=i
        dvbidx_table[i]=fidx
        bgfx.update(self.handle, offsetV, m)
        offsetV=numv(m,s)
    end
end

function dyn_vb:update(from, to)
    from = from or 1
    assert(from > 0, ("Invalid 'from': %d"):format(from))
    to = to or #self.data
    local offsetV = 0

    local s = self.stride
    for i=1, from-1 do
        local n = numv(self.data[i], s)
        offsetV = offsetV + n
    end
    for i=from, to do
        local m = self.data[i]
        bgfx.update(self.handle, offsetV, m)
        
        offsetV = offsetV + numv(m, s)
    end

    return offsetV
end

function dyn_vb:replace(fontidx,m,fontidx_table)
    local offsetV=0
    local s=self.stride
    local idxn=numv(m,s)
    local dvbidx=fontidx_table[fontidx]
    for i=1,dvbidx-1 do
        local n=numv(self.data[i],s)
        offsetV=offsetV+n
    end

    bgfx.update(self.handle,offsetV,m)
    offsetV = offsetV + idxn
 
    for i=dvbidx+1,#self.data do
        local mem = self.data[i]
        bgfx.update(self.handle, offsetV, m)
        offsetV = offsetV + numv(mem, s)  
    end
    return idxn
end


return dyn_vb