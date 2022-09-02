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

function dyn_vb:add(mem)
    local idx = #self.data+1
    self.data[idx] = mem
    local offsetV = self:update(idx, idx)
    local numV = #mem // self.stride
    return idx, offsetV-numV, numV
end

function dyn_vb:remove(idx)
    table.remove(self.data, idx)
    self:update(idx)
end

function dyn_vb:update(from, to)
    from = from or 1
    to = to or #self.data
    local offsetV = 0
    while from <= to do
        local m = self.data[from]
        bgfx.update(self.handle, offsetV, m)
        local sizebytes = #m
        local numv = sizebytes // self.stride
        offsetV = offsetV + numv
        from = from + 1
    end

    return offsetV
end

return dyn_vb