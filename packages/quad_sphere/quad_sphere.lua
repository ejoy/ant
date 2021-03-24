local ecs = ...
local world = ecs.world

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local quadsphere= require "quadsphere"
local math3d    = require "math3d"
local iquad_sphere = ecs.interface "iquad_sphere"
local iom   = world:interface "ant.objcontroller|obj_motion"
local itr   = world:interface "ant.quad_sphere|itrunk_render"

local ctrunkid      = require "trunkid_class"
local constant      = require "constant"

local function cube_vertices(radius)
    local l = constant.half_inscribed_cube_len * radius
    return {
        tlf = math3d.ref(math3d.vector(-l, l, l)),
        trf = math3d.ref(math3d.vector( l, l, l)),
        tln = math3d.ref(math3d.vector(-l, l,-l)),
        trn = math3d.ref(math3d.vector( l, l,-l)),
        blf = math3d.ref(math3d.vector(-l,-l, l)),
        brf = math3d.ref(math3d.vector( l,-l, l)),
        bln = math3d.ref(math3d.vector(-l,-l,-l)),
        brn = math3d.ref(math3d.vector( l,-l,-l)),
    }
end

local function create_trunk_entity(qseid)
    return world:create_entity{
        policy = {
            "ant.quad_sphere|trunk",
            "ant.quad_sphere|trunk_layer",
            "ant.general|name",
        },
        data = {
            transform = {},
            state = 0,
            scene_entity = true,
            material = "/pkg/ant.resources/materials/quad_sphere/quad_sphere.material",
        },
        action = {
            mount       = qseid,
        }
    }
end

local function insert_uv(c, idx, u1, v1, u2, v2, u3, v3, u4, v4)
    c[idx+0] = u1; c[idx+1] = v1;
    c[idx+2] = u2; c[idx+3] = v2;
    c[idx+4] = u3; c[idx+5] = v3;
    c[idx+6] = u4; c[idx+7] = v4;
end

local function build_mark_uv(mark_uv)
    local w, h = mark_uv.w, mark_uv.h

    local du, dv = 1/w, 1/h
    local c = {}

    local numelem = w*h

    for ih=1, h do
        local v = (ih-1)*dv
        for iw=1, w do
            local u = (iw-1)*du
            local nu, nv = u+du, v+dv
            local idx = (ih-1)*w+iw
            local off = (idx-1)*8+1
            insert_uv(c, off, u, v, nu, v, nu, nv, u, nv)

            -- rotate math.pi * 0.5
            local ir90 = numelem
            insert_uv(c, ir90+off, nu, v, nu, nv, u, nv, u, v)

            -- rotate math.pi
            local ir180 = ir90+numelem
            insert_uv(c, ir180+off, nu, nv, u, nv, u, v, nu, v)

            -- rotate math.pi * 1.5
            local ir270 = ir180+numelem
            insert_uv(c, ir270+off, u, nv, u, v, nu, v, nu, nv)
        end
    end
    c.default_uvidx = mark_uv.default_uvidx
    return c
end

local function build_color_uv(color_uv)
    local c = {}
    for _, l in ipairs(color_uv) do
        local r = l.region
        local rt = r.rect
        local u, v = rt[1], rt[2]
        local w, h = r.w, r.h
        local du, dv = (rt[3]-u)/r.w, (rt[4]-v)/r.h

        for ih=1, h do
            local nv = v+dv
            for iw=1, w do
                local nu = u+du
                insert_uv(c, #c, u, v, nu, v, nu, nv, u, nv)
                u = nu
            end
            v = nv
        end
    end
end

local function build_uv_ref(layers)
    return {
        mark_uv_coords = build_mark_uv(layers.mark_uv),
        color_uv_coords = build_color_uv(layers.color_uv)
    }
end

local qst = ecs.transform "quad_sphere_transform"
function qst.process_entity(e)
    local qs = e.quad_sphere
    local nt = qs.num_trunk
    local inv_num_trunk   = 1 / nt
    local radius = qs.radius
    assert(nt > 0 and radius > 0)

    local layers = {}
    for k, v in pairs(qs.layers) do
        layers[k] = setmetatable({}, v)
    end

    local cube_len = radius * constant.inscribed_cube_len
    local proj_trunk_len = cube_len / qs.num_trunk

    local vertices = cube_vertices(radius)

--[[
		tlf ------- trf
		/|			 /|
	   / |			/ |
	  tln ------- trn |
	   | blf ------- brf
	   |  /	       |  /
	   | /		   | /
	  bln ------- brn

            ------
           |      |
           |  2 U |
           |  (1) |
     ------+------+------+------
    |      |      |      |      |
    |  1 B |  4 L |  0 F |  5 R |
    |  (4) |  (5) |  (6) |  (7) |
     ------+------+------+------
           |      |
           |  3 D |
           |  (9) |
            ------

    all face local direction is :
    ---->
    |
    v
]]

    local inscribed_cube  = {
        vertices = vertices,
        {vertices.tln, vertices.trn, vertices.brn, vertices.bln}, --front
        {vertices.trf, vertices.tlf, vertices.blf, vertices.brf}, --back

        --be careful here
        {vertices.trf, vertices.trn, vertices.tln, vertices.tlf}, --up
        {vertices.blf, vertices.bln, vertices.brn, vertices.brf}, --down

        {vertices.tlf, vertices.tln, vertices.bln, vertices.blf}, --left
        {vertices.trn, vertices.trf, vertices.brf, vertices.brn}, --right
    }

    local trunk_entity_pool = {}

    e._quad_sphere = {
        num_trunk       = nt,
        inv_num_trunk   = inv_num_trunk,
        num_trunk_point = nt + 1,
        trunks_pre_face = nt * nt,
        radius          = radius,
        cube_len        = cube_len,
        proj_trunk_len  = proj_trunk_len,
        proj_tile_len   = proj_trunk_len * constant.inv_tile_pre_trunk_line,
        inscribed_cube  = inscribed_cube,
        trunk_entity_pool=trunk_entity_pool,
        uv_ref          = build_uv_ref(layers),
        layers          = layers,
        tile_indices    = qs.tile_indices,
        visible_trunks  = {},
    }
end

function iquad_sphere.create(name, numtrunk, radius, layers, tile_indices)
    return world:create_entity {
        policy = {
            "ant.quad_sphere|quad_sphere",
            "ant.general|name",
        },
        data = {
            quad_sphere = {
                num_trunk   = numtrunk,
                radius      = radius,
                layers      = layers,
                tile_indices= tile_indices,
            },
            name = name or "",
        }
    }
end

iquad_sphere.pack_trunkid = ctrunkid.pack_trunkid

function iquad_sphere.unpack_trunkid(trunkid)
    return ctrunkid.trunkid_face(trunkid), ctrunkid.trunkid_index(trunkid)
end

local function find_face(x, y, z)
    local ax, ay, az = math.abs(x), math.abs(y), math.abs(z)

    if ax > ay then
        if ax > az then
            return x > 0 and constant.face_index.right or constant.face_index.left, z, y, ax
        end
    else
        if ay > az then
            return y > 0 and constant.face_index.up or constant.face_index.down, x, z, ay
        end
    end

    return z > 0 and constant.face_index.back or constant.face_index.front, x, y, az
end

local function normlize_face_xy(face, x, y, maxv)
    local nx, ny = x/maxv, y/maxv
    nx, ny = (nx+1)*0.5, (ny+1)*0.5
    ny = 1-ny
    if face == constant.face_index.back or face == constant.face_index.left or face == constant.face_index.down then
        nx = 1-nx
    end
    return nx, ny
end

local function which_face(pos)
    local face, x, y, maxv = find_face(pos[1], pos[2], pos[3])
    return face, normlize_face_xy(face, x, y, maxv)
end

local function which_trunkid(pos, qs)
    local face, x, y = which_face(pos)
    local nt = qs.num_trunk
    local tx, ty = x * nt, y * nt
    local ix, iy = math.floor(tx), math.floor(ty)

    return ctrunkid.pack_trunkid(face, ix, iy)
end

iquad_sphere.which_face = which_face
iquad_sphere.which_trunkid = which_trunkid

local function tile_coord(pos, qs)
    local face, x, y = which_face(pos)
    local nt = qs.num_trunk
    local tx, ty = x * nt, y * nt
    local ix, iy = math.floor(tx), math.floor(ty)

    local cx, cy = qs.cube_len * x, qs.cube_len * y
    cx = cx - ix * qs.proj_trunk_len
    cy = cy - iy * qs.proj_trunk_len

    return ctrunkid.pack_trunkid(face, ix, iy), cx, cy
end

function iquad_sphere.trunk_coord(eid, pos)
    return tile_coord(pos, world[eid]._quad_sphere)
end

local function find_visible_trunks(pos, qs)
    local trunkid = which_trunkid(math3d.tovalue(pos), qs)
    local mask = {}
    local visible_trunks = {}
    local maxdepth = constant.visible_trunk_range
    local function fvt(tid, depth)
        if mask[tid] == nil then
            mask[tid] = true
            visible_trunks[#visible_trunks+1] = tid
        end

        local n = quadsphere.neighbor(tid, qs.num_trunk)
        if depth <= maxdepth then
            for _, t in ipairs(n) do
                fvt(t, depth+1)
            end
        end
    end

    fvt(trunkid, 0)
    return visible_trunks
end

local function find_list(l, v)
    for idx, vv in ipairs(l) do 
        if vv == v then
            return idx
        end
    end
end

local function update_visible_trunks(visible_trunks, qs, qseid)
    local update_trunks = {}
    local layers = qs.layers
    local numlayer = #layers
    local pool = qs.trunk_entity_pool
    local old_visible_trunks = qs.visible_trunks
    for _, trunkid in ipairs(visible_trunks) do
        if find_list(old_visible_trunks, trunkid) == nil then
            update_trunks[#update_trunks+1] = trunkid
            if pool[trunkid] == nil then
                local eids = {}
                for i=1, numlayer do
                    eids[#eids+1] = create_trunk_entity(qseid)
                end
                pool[trunkid] = eids
            end
        end
    end

    qs.visible_trunks = visible_trunks
    local tile_indices = qs.tile_indices
    for _, trunkid in ipairs(update_trunks) do
        local eids = pool[trunkid]
        local indices = tile_indices[trunkid]
        local covers = indices.covers
        assert(#covers == constant.tiles_pre_trunk)
        local marks = indices.mask

        for tileidx=1, constant.tiles_pre_trunk do
            --generate cover tile
            do
                local layeridx = covers[tileidx]
                local eid = eids[layeridx]
                local le = world[eid]
                local cover_tiles = le._trunk.cover_tiles
                cover_tiles[#cover_tiles+1] = {layeridx}
            end

            --generate mark tile
            local mi = marks[tileidx]
            if mi then
                for _, m in ipairs(mi) do
                    local layeridx = m.layeridx
                    local le = world[eids[layeridx]]
                    local cover_tiles = le._trunk.cover_tiles
                    cover_tiles[#cover_tiles+1] = {layeridx, m.markidx}
                end
            end
        end

        for _, eid in ipairs(eids) do
            itr.reset_trunk(eid, trunkid)
        end
    end
end

function iquad_sphere.update_visible_trunks(eid, cameraeid)
    local e = world[eid]
    local qs = e._quad_sphere

    local pos = math3d.mul(qs.radius, math3d.normalize(iom.get_position(cameraeid)))

    local visible_trunks = find_visible_trunks(pos, qs)

    update_visible_trunks(visible_trunks, qs, eid)
end

function iquad_sphere.tangent_matrix(pos)
    local n = math3d.normalize(pos)
    local r, f
    if math3d.isequal(mc.YAXIS, n) then
        r = mc.XAXIS
        f = mc.ZAXIS
    elseif math3d.isequal(mc.NYAXIS, n) then
        r = mc.XAXIS
        f = mc.NZAXIS
    else
        r = math3d.cross(mc.YAXIS, n)
        f = math3d.cross(r, n)
    end
    return math3d.set_columns(mc.IDENTITY_MAT, r, n, f, pos)
end

local function check_is_normalize(n)
    local l = math3d.length(n)
    local T<const> = 1e-6

    local c = l - 1
    return assert(-T<= c and c <= T)
end

function iquad_sphere.move(eid, pos, forward, df, dr)
    local e = world[eid]
    local qs = e._quad_sphere
    local radius = qs.radius

    if constant._DEBUG then
        check_is_normalize(forward)
    end

    local n = math3d.normalize(pos)
    local r = math3d.normalize(math3d.cross(n, forward))

    if constant._DEBUG then
        if math3d.dot(r, r) == 0 then
            error(("forward vector parallel with up vector:%s, %s"):format(math3d.tostring(forward), math3d.tostring(n)))
        end
    end

    local function move_toward(d, toward, origin)
        if d ~= 0 then
            local np = math3d.muladd(d, toward, origin)
            return math3d.mul(radius, math3d.normalize(np))
        end
        return origin
    end

    local newpos = move_toward(df, forward, pos)
    newpos = move_toward(dr, r, newpos)
    newpos = math3d.mul(qs.radius, math3d.normalize(newpos))
    return newpos
end