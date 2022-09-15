local dyn_vb = {}; dyn_vb.__index = dyn_vb

local declmgr = require "vertexdecl_mgr"
local bgfx = require "bgfx"

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

function dyn_vb:add(mem)
    local idx = #self.data+1
    self.data[idx] = mem
    local offsetV = self:update(idx, idx)
    local n = numv(mem, self.stride)
    return idx, offsetV-n, n
end

function dyn_vb:remove(idx)
    table.remove(self.data, idx)
    self:update(idx)
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

return dyn_vb