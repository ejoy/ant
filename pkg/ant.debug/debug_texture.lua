local ecs       = ...
local world     = ecs.world
local w         = world.w

local ltask     = require "ltask"
local image     = require "image"
local bgfx      = require "bgfx"
local math3d    = require "math3d"
local fastio		= require "fastio"
local dts  = ecs.system "debug_texture_system"
local idt = {}

-- https://spie.org/samples/PM159.pdf
local ADDRESS_FINDER<const> = {
    CLAMP = function (v, minv, maxv)
        return math.max(minv, math.min(v, maxv))
    end
}

local FILTER_FINDER<const> = {
    BILINEAR = function(x, y, nx, ny, px, py, load_op)
        local lt, rt, lb, rb = load_op(x, y), load_op(nx, y), load_op(x, ny), load_op(nx, ny)

        local tv = math3d.lerp(lt, rt, px)
        local bv = math3d.lerp(lb, rb, px)
        return math3d.lerp(tv, bv, py)
    end,
    TRILINEAR = function(x, y, z, nx, ny, nz, px, py, pz, t)
        local ltn, rtn = t.load_op(x, y, z, t),  t.load_op(nx, y, z, t)
        local lbn, rbn = t.load_op(x, ny, z, t), t.load_op(nx, ny, z, t)
        local tnv = math3d.lerp(ltn, rtn, px)
        local bnv = math3d.lerp(lbn, rbn, px)
        local nv = math3d.lerp(tnv, bnv, py)

        local ltf, rtf = t.load_op(x, y, nz, t),  t.load_op(nx, y, nz, t)
        local lbf, rbf = t.load_op(x, ny, nz, t), t.load_op(nx, ny, nz, t)
        local tfv = math3d.lerp(ltf, rtf, px)
        local bfv = math3d.lerp(lbf, rbf, px)

        local fv = math3d.lerp(tfv, bfv, py)
        return math3d.lerp(nv, fv, pz)
    end
}

local DEFAULT_SAMPLER<const> = {
    address = {u = ADDRESS_FINDER.CLAMP, v = ADDRESS_FINDER.CLAMP, w = ADDRESS_FINDER.CLAMP},
    filter = {
        mip = FILTER_FINDER.LINEAR,
        min = FILTER_FINDER.LINEAR,
        mag = FILTER_FINDER.LINEAR,
    }
}

local function uvw2xyz(u, v, w, t, sampler)
    local a_u, a_v, a_w = sampler.address.u(u, 0.0, 1.0), sampler.address.v(v, 0.0, 1.0), sampler.address.w(w, 0.0, 1.0)
    local OX<const>, OY<const>, OZ<const> = 0.5, 0.5, 0.5
    return a_u * t.width - OX, a_v * t.height - OY, a_w * t.depth - OZ
end

function idt.trilinear_sample(u, v, w, t)
    local iw, ih, id = 1.0 / t.width, 1.0 / t.height, 1.0 / t.depth

    local fx, fy, fz = uvw2xyz(u, v, w, t, DEFAULT_SAMPLER)
    local nfx, nfy, nfz = uvw2xyz(u + iw, v + ih, w + id, t, DEFAULT_SAMPLER)

    local x, y, z = math.floor(fx), math.floor(fy), math.floor(fz)
    local nx, ny, nz = math.floor(nfx), math.floor(nfy), math.floor(nfz)

    local px, py, pz = fx - x, fy - y, fz - z
    return FILTER_FINDER.TRILINEAR(x+1, y+1, z+1, nx+1, ny+1, nz+1, px, py, pz, t)
end

function idt.texture_precision_comparison(step, origin_memory, compressed_memory)
    local sum = 0.0

    for w = 0.0, 1.0, step do
        for v = 0.0, 1.0, step do
            for u = 0.0, 1.0, step do
                local ov = idt.trilinear_sample(u, v, w, origin_memory)
                local cv = idt.trilinear_sample(u, v, w, compressed_memory)
                sum = sum + math3d.length(math3d.sub(ov, cv))
            end
        end
    end

    return sum / (1/step)^3
end

function dts:init_world()

    local function load_rgba32f(x, y, z, t)
        local idx = z * (t.width * t.height) + y * t.width + x
        local offset = idx * 16 + 1
        local r, g, b, a = ('ffff'):unpack(t.memory, offset)
        return math3d.vector(r, g, b, 0.0)
    end

    local function load_rgb10a2(x, y, z, t)
        local idx = z * (t.width * t.height) + y * t.width + x
        local offset = idx * 4 + 1
        local p = ('I4'):unpack(t.memory, offset)
        local r, g, b, a = image.unpack_hdr_format(p, "RGB10A2")
        return math3d.vector(r, g, b, 0.0)
    end

    local function load_rg11b10f(x, y, z, t)
        local idx = z * (t.width * t.height) + y * t.width + x
        local offset = idx * 4 + 1
        local p = ('I4'):unpack(t.memory, offset)
        local r, g, b, a = image.unpack_hdr_format(p, "RG11B10F")
        return math3d.vector(r, g, b, 0.0)
    end

    local ob1 = "D://vaststars2/startup/res/windows-direct3d11/texture/tonemapping_lut_rgba32f.texture_bd669bc2d8168ab95c88d196044f86efea78d244/main.bin"
    local info1, content1 = image.parse(fastio.readall_f(ob1), true, "RGBA32F")
    local t1 = {
        width = 32, height = 32, depth = 32, memory = content1, load_op = load_rgba32f
    }
    local ob2 = "D://vaststars2/startup/res/windows-direct3d11/texture/tonemapping_lut_rgb10a2.texture_6f79234572b1b65d0dc33e1f431119002e20259b/main.bin"
    local info2, content2 = image.parse(fastio.readall_f(ob2), true, "RGB10A2")
    local t2 = {
        width = 32, height = 32, depth = 32, memory = content2, load_op = load_rgb10a2
    }
    local ob3 = "D://vaststars2/startup/res/windows-direct3d11/texture/tonemapping_lut_rg11b10f.texture_ec7c73f5ac33eb0ab96bd74801e0f517b4a1c91a/main.bin"
    local info3, content3 = image.parse(fastio.readall_f(ob2), true, "RG11B10F")
    local t3 = {
        width = 32, height = 32, depth = 32, memory = content3, load_op = load_rg11b10f
    }

    local avg1 = idt.texture_precision_comparison(0.05, t1, t2)
    local avg2 = idt.texture_precision_comparison(0.05, t1, t3)
    local stop = 1
end

return idt