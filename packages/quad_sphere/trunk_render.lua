local ecs = ...
local world = ecs.world

local ctrunkid  = require "trunkid_class"
local constant  = require "constant"

local bgfx      = require "bgfx"
local math3d    = require "math3d"

local ies = world:interface "ant.scene|ientity_state"
local itr = ecs.interface "itrunk_render"

local surface_point = ctrunkid.surface_point

function itr.reset_trunk(eid, trunkid)
    local e = world[eid]
    local qseid = e.parent
    local qs = assert(world[qseid])._quad_sphere

    ies.set_state(eid, "visible", true)

    local radius    = qs.radius
    local hd, vd, basept = ctrunkid(trunkid, qs):tile_delta(constant.inv_tile_pre_trunk_line)
    local vertices = {}
    local tptl = constant.tile_pre_trunk_line

    local cache = {}
    local function get_pt(ih, iv)
        local idx = iv * (tptl+1) + ih
        local p = cache[idx]
        if  p == nil then
            p = math3d.muladd(ih,  hd,  math3d.muladd(iv,vd, basept))
            p = math3d.tovalue(surface_point(radius, p))
            cache[idx] = p
        end

        return p
    end

    local cover_tiles = e._trunk.cover_tiles

    local uvref = qs.layers.uv_ref
    local mc, cc = uvref.mask_uv_coords, uvref.color_uv_coords
    for _, ct in ipairs(cover_tiles) do
        local tileidx, layeridx, maskidx = ct[1], ct[2], ct[3]
        local ih, iv = tileidx % tptl, tileidx // tptl
        for vidx, p in ipairs{
            get_pt(ih-1, iv-1),
            get_pt(ih,   iv-1),
            get_pt(ih,   iv),
            get_pt(ih-1, iv),
        } do
            vertices[#vertices+1] = p[1]
            vertices[#vertices+1] = p[2]
            vertices[#vertices+1] = p[3]

            local function set_uvidx(idx, coords)
                local uvidx
                if idx then
                    uvidx = (idx-1)*8+(vidx-1)*2
                else
                    uvidx = coords.default_uvidx or 0
                end
                vertices[#vertices+1] = coords[uvidx+1]
                vertices[#vertices+1] = coords[uvidx+2]
            end

            set_uvidx(layeridx, cc)
            set_uvidx(maskidx, mc)
        end
    end

    local function calc_aabb()
        local hf, hc = math.floor(tptl*0.5), math.ceil(tptl*0.5)
        local corner_indices = {
            0, 0,
            tptl-1, 0,
            tptl-1, tptl-1,
            0, tptl-1,
            hf, hf,
            hc, hc,
        }

        local aabb = math3d.aabb()
        local pp = {}
        for i=1, #corner_indices, 2 do
            local ih, iv = corner_indices[i], corner_indices[i+1]
            pp[#pp+1] = get_pt(ih, iv)
        end

        math3d.aabb_append(aabb, table.unpack(pp))
        return aabb
    end

    e._bounding.aabb.m = calc_aabb()
    local rc = e._rendercache
    rc.aabb = e._bounding.aabb
    rc.ib = constant.trunk_ib.buffer
    local vb = rc.vb
    bgfx.update(vb.handles[1], 0, bgfx.memory_buffer("fffffff", vertices), constant.vb_layout.handle)
end