local ecs = ...
local world = ecs.world

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local math3d    = require "math3d"
local iquad_sphere = ecs.interface "iquad_sphere"
local iom   = world:interface "ant.objcontroller|obj_motion"
local itr   = world:interface "ant.quad_sphere|itrunk_render"

local ctrunkid      = require "trunkid_class"
local constant      = require "constant"
local surface_point = ctrunkid.surface_point

--[[

		tlf ------- trf
		/|			 /|
	   / |			/ |
	  tln ------- trn |
	   | blf ------- brf
	   |  /	       |  /
	   | /		   | /
	  bln ------- brn
]]

--{F, B, U, D, L, R}
local face_index<const> = {
    front   = 0,
    back    = 1,

    top     = 2,
    bottom  = 3,

    left    = 4,
    right   = 5,
}

local inscribed_cube_len<const>         = math.sqrt(3) * 2.0/3.0
local half_inscribed_cube_len<const>    = inscribed_cube_len * 0.5

local function cube_vertices(radius)
    local l = half_inscribed_cube_len * radius
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

    local cube_len = radius * inscribed_cube_len
    local proj_trunk_len = cube_len / qs.num_trunk

    local vertices = cube_vertices(radius)

    local inscribed_cube  = {
        vertices = vertices,
        {vertices.tln, vertices.trn, vertices.brn, vertices.bln}, --front
        {vertices.trf, vertices.tlf, vertices.blf, vertices.brf}, --back

        {vertices.tlf, vertices.trf, vertices.trn, vertices.tln}, --up
        {vertices.bln, vertices.brn, vertices.brf, vertices.blf}, --down

        {vertices.tlf, vertices.tln, vertices.bln, vertices.blf}, --left
        {vertices.trn, vertices.trf, vertices.brf, vertices.brn}, --right
    }

    local function trunk_distance(face, x1, x2)
        local fv = inscribed_cube[face+1]
        local hd, vd, basetpt = ctrunkid.quad_delta(fv, inv_num_trunk)
        local p1, p2 = math3d.muladd(x1, hd, basetpt), math3d.muladd(x2, hd, basetpt)
        local sp1, sp2 = surface_point(radius, p1), surface_point(radius, p2)
        return math3d.length(math3d.sub(sp2, sp1))
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
        trunk_distance  = trunk_distance(0, 0, 1),
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
            return x > 0 and face_index.right or face_index.left, z, y, ax
        end
    else
        if ay > az then
            return y > 0 and face_index.top or face_index.bottom, x, z, ay
        end
    end

    return z > 0 and face_index.back or face_index.front, x, y, az
end

local function normlize_face_xy(face, x, y, maxv)
    local nx, ny = x/maxv, y/maxv
    nx, ny = (nx+1)*0.5, (ny+1)*0.5
    ny = 1-ny
    if face == face_index.back or face == face_index.left or face == face_index.bottom then
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

function iquad_sphere.update_visible_trunks(eid, cameraeid)
    local e = world[eid]
    local qs = e._quad_sphere

    local pos = iom.get_position(cameraeid)

    local visible_trunks = {}

    local trunkid = which_trunkid(math3d.tovalue(pos), qs)
    local tm = iquad_sphere.tangent_matrix(pos)
    local r, f = math3d.index(tm, 1), math3d.index(tm, 3)
    local vtr = constant.visible_trunk_range
    local trunkdis = qs.trunk_distance

    for i=-vtr, vtr do
        local dv = math3d.mul(i * trunkdis, f)
        for j=-vtr, vtr do
            if i~=0 and j~=0 then
                local dh = math3d.mul(j * trunkdis, r)
                local np = math3d.add(math3d.add(pos, dh), dv)
                local ntid = which_trunkid(math3d.tovalue(np), qs)
                visible_trunks[#visible_trunks+1] = ntid
            else
                visible_trunks[#visible_trunks+1] = trunkid
            end
        end
    end

    local tep = qs.trunk_entity_pool
    if #qs.visible_trunks == 0 then
        local l = vtr*2+1
        for i=1, l*l do
            tep[i] = create_trunk_entity(eid)
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

    local trunkid = which_trunkid(math3d.tovalue(pos), qs)

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

    local newtrunkid = which_trunkid(math3d.tovalue(newpos), qs)

    if trunkid ~= newtrunkid then
        iquad_sphere.set_trunkid(eid, newtrunkid)
    end

    return newpos
end