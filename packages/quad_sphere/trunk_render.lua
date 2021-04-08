local ecs = ...
local world = ecs.world

local ctrunkid  = require "trunkid_class"
local constant  = require "constant"

local bgfx      = require "bgfx"
local math3d    = require "math3d"

local ies = world:interface "ant.scene|ientity_state"
local itr = ecs.interface "itrunk_render"

local surface_point = ctrunkid.surface_point

local mask_names = {
    U = 1, -- like U
    C = 2, -- circle/center
    S = 3, -- /, slope, triangle
    L = 4, -- line
    B = 5, -- bight, corner
    F = 6, -- Full
}

local halfpi<const>, onehalfpi<const>, twopi<const> = math.pi * 0.5, math.pi * 1.5, math.pi*2
local function get_rotate_name(n, rotateidx)
    if 0<= rotateidx and rotateidx <= 3 then
        return mask_names[n] + 6 * rotateidx
    end
    error("invalid rotateidx:", rotateidx)
end

local function pack_item(tileidx, maskidx)
    return tileidx|(maskidx << 16)
end

local function build_mask_indices(covers_set)
    if next(covers_set) == 0 then
        return
    end
    
    local c = constant.tile_pre_trunk_line
    local indices = {}
    -- range from [2, c-1] for skip edge case
    for j=2, c-1 do
        for i=2, c-1 do
            local nl = (j-1) * c
            local tileidx = nl + i
            if covers_set[tileidx] == nil then
                local last_l = (j-2) * c
                local next_l = j * c
    
                local neighbors = {left=tileidx-1, right=tileidx+1, up=last_l+i, down=next_l+i}    --left, right, up, down
                local neighbor_covers = {}

                local covercount = 0
                for k, n in pairs(neighbors) do
                    if covers_set[n] then
                        neighbor_covers[k] = true
                        covercount = covercount+1
                    end
                end

                if covercount == 4 then
                    indices[pack_item(tileidx, mask_names.C)] = true
                elseif covercount == 3 then
                    local function find_rotate_idx()
                        local idxdirname<const> = {up=0, right=1, down=2, left=3,}
                        local dirnameidx<const> = {"up", "right", "down", "left"}
                        for _, n in ipairs(dirnameidx) do
                            if neighbor_covers[n] == nil then
                                return idxdirname[n]
                            end
                        end
                        error("can not be here")
                    end

                    indices[pack_item(tileidx, get_rotate_name('U', find_rotate_idx()))] = true
                elseif covercount == 2 then
                    if neighbor_covers.left and neighbor_covers.right then
                        indices[pack_item(tileidx,  get_rotate_name("L", 2))] = true
                        indices[pack_item(tileidx,  mask_names.L)] = true
                    elseif neighbor_covers.up and neighbor_covers.down then
                        indices[pack_item(tileidx,  get_rotate_name("L", 1))] = true
                        indices[pack_item(tileidx,  get_rotate_name("L", 3))] = true
                    elseif neighbor_covers.up and neighbor_covers.right then
                        indices[pack_item(tileidx,  get_rotate_name("S", 3))] = true
                    elseif neighbor_covers.right and neighbor_covers.down then
                        indices[pack_item(tileidx,  mask_names.S)] = true
                    elseif neighbor_covers.down and neighbor_covers.left then
                        indices[pack_item(tileidx,  get_rotate_name("S", 1))] = true
                    elseif neighbor_covers.left and neighbor_covers.up then
                        indices[pack_item(tileidx,  get_rotate_name("S", 2))] = true
                    else
                        error("invalid")
                    end
                elseif covercount == 1 then
                    local nameidx<const> = {left=2, right=0, up=3, down=1}
                    local k = next(neighbor_covers)
                    indices[pack_item(tileidx,  get_rotate_name("L", nameidx[k]))] = true
                else
                    assert(covercount == 0)
                    local corner_tiles<const> = {
                        tileidx-c-1, tileidx-c+1,   -- upleft, upright
                        tileidx+c-1, tileidx+c+1,   -- downleft, downright
                    }
                    
                    for idx, ctileidx in ipairs(corner_tiles) do
                        if covers_set[ctileidx] then
                            indices[pack_item(tileidx,  get_rotate_name("B", idx-1))] = true
                        end
                    end
                end
            end
        end
    end

    return indices
end

function itr.build_tile_indices(tile_indices, trunkid, backgroundidx)
    -- need cache
    local indices = {}
    local trunk_tile_indices = tile_indices[trunkid]
    for tileidx=1, constant.tiles_pre_trunk do
        local layeridx = trunk_tile_indices[tileidx]
        local l = indices[layeridx]
        if l == nil then
            l = {
                covers = {}
            }
            indices[layeridx] = l
        end

        l.covers[tileidx] = true
    end

    for layeridx, l in pairs(indices) do
        if layeridx ~= backgroundidx then
            l.masks = build_mask_indices(l.covers)
        end
    end

    return indices
end

function itr.reset_trunk(eid, trunkid, layeridx, cover_tiles)
    local e = world[eid]
    local qseid = e.parent
    local qs = assert(world[qseid])._quad_sphere

    ies.set_state(eid, "visible", true)

    local trunk = e._trunk
    trunk.cover_tiles = cover_tiles
    trunk.layeridx = layeridx
    trunk.trunkid = trunkid

    local ismask = e.ismask

    local radius    = qs.radius
    local hd, vd, basept = ctrunkid(trunkid, qs):tile_delta(constant.inv_tile_pre_trunk_line)
    local vertices = {}
    local tptl = constant.tile_pre_trunk_line
    local vptl = constant.vertices_pre_tile_line
    local cache = {}
    local function get_pt(ih, iv)
        local vidx = iv*vptl+ih+1    --base 1
        local p = cache[vidx]
        if  p == nil then
            p = math3d.muladd(ih, hd, math3d.muladd(iv, vd, basept))
            p = math3d.tovalue(surface_point(radius, p))
            cache[vidx] = p
        end

        return p
    end

    local uvref = qs.layers.uv_ref
    local mc, cc = uvref.mask_uv_coords, uvref.color_uv_coords

    local layeruvidx = (layeridx-1)*8
    local layeruv = {
        cc[layeruvidx+1], cc[layeruvidx+2],
        cc[layeruvidx+3], cc[layeruvidx+4],
        cc[layeruvidx+5], cc[layeruvidx+6],
        cc[layeruvidx+7], cc[layeruvidx+8],
    }

    local function add_layer_uv(vertices, vidx)
        local idx = (vidx-1)*2
        vertices[#vertices+1] = layeruv[idx+1]
        vertices[#vertices+1] = layeruv[idx+2]
    end

    local function add_layer_mask_uv(vertices, vidx, maskidx)
        add_layer_uv(vertices, vidx)
        local uvidx = (maskidx-1)*8+(vidx-1)*2
        vertices[#vertices+1] = mc[uvidx+1]
        vertices[#vertices+1] = mc[uvidx+2]
    end

    local add_uv
    if ismask then 
        add_uv = add_layer_mask_uv
    else
        add_uv = add_layer_uv
    end

    for idx in pairs(cover_tiles) do
        local tileidx = idx & 0x0000ffff
        local maskidx = (idx & 0xffff0000) >> 16
        local tileidx0 = tileidx-1  --base 0
        local ih, iv = tileidx0 % tptl, tileidx0 // tptl    --ih, iv base 0
        for vidx, p in ipairs{
            get_pt(ih,  iv),
            get_pt(ih+1,iv),
            get_pt(ih+1,iv+1),
            get_pt(ih,  iv+1),
        } do
            vertices[#vertices+1] = p[1]
            vertices[#vertices+1] = p[2]
            vertices[#vertices+1] = p[3]

            add_uv(vertices, vidx, maskidx)
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
    local numv = #vertices
    if numv > 0 then
        local rc = e._rendercache
        rc.aabb = e._bounding.aabb

        local vb = rc.vb
        local bufdesc = ismask and "fffffff" or "fffff" --p3|t20|t21 or p3|t20
        vb.start = 0
        vb.num = #vertices / #bufdesc

        local tilenum = vb.num / 4
        local ib = rc.ib

        ib.num = tilenum * 6
        ib.handle = constant.trunk_ib.buffer.handle

        local layout = ismask and constant.vb_layout.mask or constant.vb_layout.cover
        bgfx.update(vb.handles[1], 0, bgfx.memory_buffer(bufdesc, vertices), layout.handle)
    end
end