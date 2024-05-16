local mu = import_package "ant.math".util
local layoutmgr = import_package "ant.render.core".layout
local math3d = require "math3d"

local function buffer_desc(layout)
    local offset = 0
    local desc = {}
    for l in layout:gmatch "[^|]+" do
        local n = l:sub(1, 1)
        local stride = layoutmgr.elem_size(l)
        desc[n] = {
            offset  = offset,
            stride  = stride,
            num     = l:sub(2, 2) - '0',
            type    = l:sub(6, 6),
            layout  = l,
            load    = function (self, data)
                local start = self.offset
                return data:sub(start+1, start+self.stride)
            end,
        }

        offset = offset + stride
    end

    return desc
end

local function align_vec4_str(s)
    local n = 16 - #s
    if n == 0 then
        return s
    end
    assert(n == 4 or n == 8)
    local nn = n // 4
    return s .. ('f'):rep(nn):pack(0)
end

local function is_quat_tbn(desc)
    return desc.T and desc.T.num == 4 and desc.n == nil
end

local function compress_quat(q)
    local x, y, z, w = math3d.index(q, 1, 2, 3, 4)
    return ('hhhh'):pack(mu.f2h(x), mu.f2h(y), mu.f2h(z), mu.f2h(w))
end

local meshmt = {
    init = function (self)
        local layout = self.meshres.vb.declname
        self.desc = buffer_desc(layout)
        self.vb_stride = layoutmgr.layout_stride(layout)
        self.pack_tangent_frame = is_quat_tbn(self.desc)
    
        assert(self.desc.p.num == 3)
    end,
    numv = function (self)
        return self.meshres.vb.num
    end,
    numi = function(self)
        return self.meshres.ib and self.meshres.ib.num or 0
    end,
    load_transform = function(self)
        return self.transform
    end,
    loadvertex = function (self, iv)
        local v = self._vertices[iv]
        if nil == v then
            local vb = self.meshres.vb
            local s = self.vb_stride
            local start = (iv-1)*s
            v = vb.str:sub(start+1, start+s)
            self._vertices[iv] = v
        end
        return v
    end,
    --iv base0
    loadpos = function(self, iv, transform)
        assert(self:numv() >= iv)
        local v = self:loadvertex(iv)

        local desc = assert(self.desc.p)
        assert(desc.type == 'f')
        local t = desc:load(v)
        assert(desc.num == 3)
        assert(#t == desc.num * 4) -- 4 for sizeof(float)
        local p = math3d.transform(transform, math3d.vector(align_vec4_str(t)), 1)
        return math3d.serialize(p):sub(1, 12)
    end,
    loadnormal = function(self, iv, transform)
        assert(self:numv() >= iv)
        local v = self:loadvertex(iv)

        if self.pack_tangent_frame then
            local desc = assert(self.desc.T)
            assert(desc.num == 4)
            local data = desc:load(v)
            local normal, tangent
            if desc.type == 'f' then
                assert(#data == desc.n * 4) -- 4 for sizeof(float)
                normal, tangent = mu.unpack_tangent_frame(math3d.quaternion(data))
            elseif desc.type == 'i' then
                local T1, T2, T3, T4 = ('h'):rep(4):unpack(data)
                T1, T2, T3, T4 = mu.h2f(T1), mu.h2f(T2), mu.h2f(T3), mu.h2f(T4)
                normal, tangent = mu.unpack_tangent_frame(math3d.quaternion(T1, T2, T3, T4))
            else
                error "Invalid quat data in vertex"
            end

            local sign = math3d.index(tangent, 4)
            normal = math3d.transform(transform, normal, 0)
            tangent = math3d.transform(transform, tangent, 0)
            local x, y, z = math3d.index(tangent, 1, 2, 3)
            tangent = math3d.vector(x, y, z, sign)
            return compress_quat(mu.pack_tangent_frame(normal, tangent))

        elseif self.desc.n then
            local desc = assert(self.desc.n)
            assert(desc.type == 'f')
            local t = desc:load(v)
            assert(desc.num == 3)
            assert(#t == desc.num * 4) -- 4 for sizeof(float)
            local normal = math3d.transform(transform, math3d.vector(align_vec4_str(t)), 0)
            return math3d.serialize(normal):sub(1, 12)
        end
    end,
    loadindices = function (self, iv)
        assert(self:numv() >= iv)
        local v = assert(self:loadvertex(iv))
        local desc = assert(self.desc.i)

        assert(desc.num == 4)
        local data = desc:load(v)
        local i1, i2, i3, i4
        if desc.type == "i" then
            assert(#data == 8)
            i1, i2, i3, i4 = ("H"):rep(4):unpack(data)
            assert(0 <= i1 and i1 < 65536)
            assert(0 <= i2 and i2 < 65536)
            assert(0 <= i3 and i3 < 65536)
            assert(0 <= i4 and i4 < 65536)
        elseif desc.type == "u" then
            assert(#data == 4)
            i1, i2, i3, i4 = ("B"):rep(4):unpack(data)
            assert(0 <= i1 and i1 < 256)
            assert(0 <= i2 and i2 < 256)
            assert(0 <= i3 and i3 < 256)
            assert(0 <= i4 and i4 < 256)
        else
            error(("Invalid index type, only i/u is support:%s, %s"):format(desc.i, desc.layout))
        end
        return {i1, i2, i3 ,i4}
    end,
    loadweights = function (self, iv)
        assert(self:numv() >= iv)
        local v = self:loadvertex(iv)
        local desc = assert(self.desc.w)

        local data = desc:load(v)
        assert(desc.num == 4)
        local w1, w2, w3, w4
        if desc.type == 'f' then
            w1, w2, w3, w4 = ('f'):rep(4):unpack(data)
        elseif desc.type == 'i' then
            local _ = desc.layout:sub(4, 4) == 'n' or error(("Invalid layout, type:%s, should use as normalize data:%s"):format(desc.type, desc.layout:sub(4, 4)))
            local _ = desc.layout:sub(5, 5) == 'i' or error(("Invalid layout, type:%s, weight should be pack in asInt"):format(desc.type, desc.layout:sub(5, 5)))
            w1, w2, w3, w4 = ('h'):rep(4):unpack(data)
            w1, w2, w3, w4 = mu.h2f(w1), mu.h2f(w2), mu.h2f(w3), mu.h2f(w4)
        else
            error "Invalid weight type"
        end
        assert(w1 >= 0 and w2 >= 0 and w3 >= 0 and w4 >= 0)
        return {w1, w2, w3, w4}
    end,
}

return {
    create = function (meshres, transform)
        local o = setmetatable({
            meshres     = meshres,
            transform   = transform,
            _vertices   = {},
        }, {__index=meshmt})
        o:init()
        return o
    end,
    is_quat_tbn = is_quat_tbn,
}