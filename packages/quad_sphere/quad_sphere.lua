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
local surface_point = ctrunkid.surface_point

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
            "ant.general|name",
        },
        data = {
            transform = {},
            state = 0,
            scene_entity = true,
            material = "/pkg/ant.resources/materials/simpletri.material",
            trunk = {
                qseid = qseid,
            },
        },
    }
end

local qst = ecs.transform "quad_sphere_transform"
function qst.process_entity(e)
    local qs = e.quad_sphere
    local nt = qs.num_trunk
    local inv_num_trunk   = 1 / nt
    local radius = qs.radius
    assert(nt > 0 and radius > 0)

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

    local function trunk_radian(face, x)
        local fv = inscribed_cube[face+1]
        local hd, vd, basetpt = ctrunkid.quad_delta(fv, inv_num_trunk)
        local p1, p2, p3, p4 =  math3d.muladd(x,    hd, basetpt),
                                math3d.muladd(x+1,  hd, basetpt),
                                math3d.muladd(x+2,  hd, basetpt),
                                math3d.muladd(x+3,  hd, basetpt)

        local sp1, sp2, sp3, sp4 =  math3d.mul(radius, math3d.normalize(p1)),
                                    math3d.mul(radius, math3d.normalize(p2)),
                                    math3d.mul(radius, math3d.normalize(p3)),
                                    math3d.mul(radius, math3d.normalize(p4))
        local d1, d2, d3 = math3d.sub(sp2, sp1), math3d.sub(sp3, sp2), math3d.sub(sp4, sp3)

        local pp = 1
        
        -- local fv = inscribed_cube[face+1]
        -- local hd, vd, basetpt = ctrunkid.quad_delta(fv, inv_num_trunk)
        -- local p1, p2, p3, p4 =  math3d.muladd(x, hd, basetpt),
        --                         math3d.muladd(x+1, hd, basetpt),
        --                         math3d.muladd(x+2, hd, basetpt),
        --                         math3d.muladd(x+3, hd, basetpt)

        -- local n1, n2, n3, n4 =  math3d.normalize(p1),
        --                         math3d.normalize(p2),
        --                         math3d.normalize(p3),
        --                         math3d.normalize(p4)

        -- local c1, c2, c3 = math3d.dot(n1, n2), math3d.dot(n2, n3), math3d.dot(n3, n4)

        -- local r = math.acos(math3d.dot(n1, n2))

        -- local sp1, sp2 = math3d.mul(radius, n1), math3d.mul(radius, n2)

        -- local tm = iquad_sphere.tangent_matrix(basetpt)
        -- local f = math3d.index(tm, 3)
        -- local q1 = math3d.quaternion{axis=f, r=r}

        -- local pp = math3d.transform(q1, sp1, 1)

        -- local ppp = 1
    end

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
        --trunk_radian    = trunk_radian(0, 0, 1),
        inscribed_cube  = inscribed_cube,
        trunk_entity_pool=trunk_entity_pool,
        visible_trunks  = {},
    }
end

function iquad_sphere.create(name, numtrunk, radius)
    return world:create_entity {
        policy = {
            "ant.quad_sphere|quad_sphere",
            "ant.general|name",
        },
        data = {
            quad_sphere = {
                num_trunk   = numtrunk,
                radius      = radius,
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

-- function iquad_sphere.set_trunkid(eid, trunkid)
--     local e = world[eid]
--     local qs = e._quad_sphere
--     if qs.trunkid ~= trunkid then
--         qs.trunkid = trunkid
--         ientity_state.set_state(eid, "visible", true)
--     end

--     local vertices, aabb = ctrunkid.tile_vertices(trunkid, qs, constant.tile_pre_trunk_line)
--     e._bounding.aabb.m = aabb
--     local rc = e._rendercache
--     rc.aabb = e._bounding.aabb

--     local vb = rc.vb
--     local poshandle = vb.handles[1]
--     bgfx.update(poshandle, 0, bgfx.memory_buffer("fff", vertices), quad_sphere_vertex_layout.handle)
-- end

-- local function find_visible_trunks(pos)
--     local visible_trunks = {}

--     local trunkid = which_trunkid(math3d.tovalue(pos), qs)
--     local corners = ctrunkid(trunkid, qs):corners_3d()
--     local ptl = qs.proj_trunk_len

--     local vtr = constant.visible_trunk_range

--     local function direction(pt, ih, iv)
--         local tm = iquad_sphere.tangent_matrix(pt)
--         local r, f = math3d.index(tm, 1), math3d.index(tm, 3)
--         if ih < 0 then
--             r = math3d.inverse(r)
--         end

--         if iv < 0 then
--             f = math3d.inverse(f)
--         end

--         return r, f
--     end


--     local mark = {}

--     local function find_trunkid(pt, hnext, vnext)
--         local r, f = direction(pt, 0, 0)
--         local np = pt
--         for iv in vnext() do
--             if iv ~= 0 then
--                 np = math3d.mul(ptl, f, np)
--             end
--             for ih in hnext() do
--                 if iv ~= 0 or ih ~= 0 then
--                     np = math3d.muladd(ptl, r, np)
--                     local ntid = which_trunkid(math3d.tovalue(np), qs)
--                     assert(mark[ntid] == nil)
--                     mark[ntid] = true
--                     visible_trunks[#visible_trunks+1] = ntid
    
--                     r, f = direction(np, iv, ih)
--                 end
--             end
--         end
--     end

--     find_trunkid(corners[2], )


--     local mark = {}
--     for i=-vtr, vtr do
--         local hq = math3d.quaternion{axis=f, r=i*trunkradian}
--         for j=-vtr, vtr do
--             local ntid
--             if i==0 and j==0 then
--                 ntid = trunkid
--             else
--                 local vq = math3d.quaternion{axis=r, r=j*trunkradian}
--                 local q = math3d.mul(hq, vq)
--                 local np = math3d.transform(q, pos, 1)
--                 print(math3d.tostring(np), math3d.length(np), i, j)
--                 ntid = which_trunkid(math3d.tovalue(np), qs)
--             end
            

--         end
--     end
-- end


local function find_visible_trunks(pos, qs)
    local trunkid = which_trunkid(math3d.tovalue(pos), qs)
    local mask = {}
    local visible_trunks = {}
    local maxdepth = constant.visible_trunk_range
    local function fvt(tid, depth)
        if mask[tid] == nil then
            mask[tid] = true
            visible_trunks[#visible_trunks+1] = tid

            print("face:", ctrunkid.trunkid_face(tid), "tx, ty:", ctrunkid.trunkid_index(tid))
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

local function update_visible_trunks(visible_trunks, qs, qseid)
    local tep = qs.trunk_entity_pool
    if #qs.visible_trunks == 0 then
        for idx, tid in ipairs(visible_trunks) do
            tep[idx] = create_trunk_entity(qseid)
            itr.reset_trunk(tep[idx], tid)
        end
    else
        local remove_trunkids = {}
        local function find_trunkid(vt, tid)
            for _, tt in ipairs(vt) do
                if tt == tid then
                    return tt
                end
            end
        end

        local old_trunkids = {}
        for idx, tid in ipairs(qs.visible_trunks) do
            if nil == find_trunkid(visible_trunks, tid) then
                remove_trunkids[#remove_trunkids+1] = idx
            else
                old_trunkids[tid] = idx
            end
        end

        if #remove_trunkids > 0 then
            for _, tid in ipairs(visible_trunks) do
                if nil == old_trunkids[tid] then
                    local poolidx = remove_trunkids[#remove_trunkids]
                    remove_trunkids[#remove_trunkids] = nil
                    local teid = tep[poolidx]
                    itr.reset_trunk(teid, tid)
                end
            end
        end
        assert(#remove_trunkids == 0)
    end
    qs.visible_trunks = visible_trunks
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