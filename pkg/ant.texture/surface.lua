local s = {}
--Pixel coordinate system and texel coordinate system are the same as d3d10
--https://learn.microsoft.com/en-us/windows/win32/direct3d10/d3d10-graphics-programming-guide-resources-coordinates

local function uv2xy(sampler, u, v, w, h)
    local addr = sampler.address
    return addr.u(u)*w, addr.v(v)*h
end

local floor = math.floor

local function create_sample_box(so, sampler, u, v)
    local w, h = assert(so.w), assert(so.h)

    local x, y = uv2xy(sampler, u, v, w, h)

    --texel index
    local tx, ty = math.max(0, floor(x - 0.5)), math.max(0, floor(y - 0.5))
    local ntx, nty = math.min(w-1, tx+1), math.min(h-1, ty+1)

    local ltx, lty = tx + 0.5, ty + 0.5 --left top point
    local px, py = x - ltx, y - lty
    local _ = (px >= 0 and py >= 0) or error(("px and py should >= 0, px = %f, py = %f"):format(px, py))
    return {
        tx=tx, ty=ty,
        ntx=ntx, nty=nty,
        px=px, py=py,
    }
end

function s.sample(so, sampler, u, v)
    local box = create_sample_box(so, sampler, u, v)
    return sampler.filter(so, box)
end

return s