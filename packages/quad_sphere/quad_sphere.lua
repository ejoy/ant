local ecs = ...
local world = ecs.world

local mathpkg   = import_package "ant.math"
local mc        = mathpkg.constant

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr

local math3d    = require "math3d"
local bgfx      = require "bgfx"

local iquad_sphere = ecs.interface "iquad_sphere"
local ientity = world:interface "ant.render|entity"
local ientity_state = world:interface "ant.scene|ientity_state"
local iom   = world:interface "ant.objcontroller|obj_motion"

local tile_pre_trunk_line<const>    = 32
local vertices_pre_tile_line<const> = tile_pre_trunk_line+1
local vertices_per_trunk<const>     = vertices_pre_tile_line * vertices_pre_tile_line
local tiles_pre_trunk<const>        = tile_pre_trunk_line * tile_pre_trunk_line

local visible_trunk_range<const>        = 4
local visible_trunk_num<const>          = visible_trunk_range * visible_trunk_range
local visible_trunk_indices_num<const>  = visible_trunk_num * tiles_pre_trunk * 6
local quad_sphere_vertex_layout<const>  = declmgr.get "p3"

--[[
    quad indices
    1 ----- 2
    |       |
    |       |
    0 ----- 3
]]

local function create_face_quad_indices(quad_pre_line)
    local indices = {}
    local vertex_num = quad_pre_line+1
    for i=0, quad_pre_line-1 do
        local is = i * vertex_num
        local is_n = (i+1) * vertex_num
        for j=0, quad_pre_line-1 do
            indices[#indices+1] = is_n+ j
            indices[#indices+1] = is+j
            indices[#indices+1] = is+j+1

            indices[#indices+1] = is+j+1
            indices[#indices+1] = is_n+j+1
            indices[#indices+1] = is_n+j
        end
    end
    return indices
end

local trunk_indices = create_face_quad_indices(tile_pre_trunk_line)

local function quad_line_indices(tri_indices)
    local indices = {}

    for it=1, #tri_indices, 3 do
        local v1, v2, v3 = tri_indices[it], tri_indices[it+1], tri_indices[it+2]
        indices[#indices+1] = v1
        indices[#indices+1] = v2

        indices[#indices+1] = v2
        indices[#indices+1] = v3
    end

    return indices
end

local trunk_line_indices = quad_line_indices(trunk_indices)

local function create_quad_sphere_trunk_ib()
    local numindices_pre_trunk = #trunk_indices
    for i=1, visible_trunk_num-1 do
		local offset = i * vertices_per_trunk
		for j=1, numindices_pre_trunk do
			trunk_indices[#trunk_indices+1] = offset + trunk_indices[j]
		end
	end

    return {
        start = 0,
        num = #trunk_indices,
        handle = bgfx.create_index_buffer(bgfx.memory_buffer("w", trunk_indices))
    }
end
local visible_trunk_ib<const> = create_quad_sphere_trunk_ib()

local qsbt = ecs.transform "quad_sphere_bounding_transform"
function qsbt.process_entity(e)
    e._bounding.aabb = math3d.ref(math3d.aabb())
end

local qsmt = ecs.transform "quad_sphere_mesh_transform"
function qsmt.process_entity(e)
    local rc = e._rendercache

    local numvertices = visible_trunk_num * vertices_per_trunk   --duplicate vertices on trunk edge
    rc.vb = {
        start = 0,
        num = numvertices,
        handles = {
            bgfx.create_dynamic_vertex_buffer(numvertices, quad_sphere_vertex_layout.handle, "a"),
        }
    }

    assert(numvertices < 65536, "too many vertices")
    rc.ib = visible_trunk_ib
end

local qst = ecs.transform "quad_sphere_transform"
function qst.process_entity(e)
    local qs = e.quad_sphere
    local nt = qs.num_trunk
    local radius = qs.radius
    assert(nt > 0 and radius > 0)

    local cube_len = radius * math.sqrt(2)
    local proj_trunk_len = cube_len / qs.num_trunk
    e._quad_sphere = {
        num_trunk       = nt,
        radius          = radius,
        cube_len        = cube_len,
        proj_trunk_len  = proj_trunk_len,
        proj_trunk_unit = proj_trunk_len / tile_pre_trunk_line,
        trunks_pre_face = nt * nt,
    }
end

function iquad_sphere.create(name, numtrunk, radius)
    --local verties, indices = geo.quad_sphere(numtrunk, radius)
    return world:create_entity {
        policy = {
            "ant.quad_sphere|quad_sphere",
            "ant.render|debug_mesh_bounding",
            "ant.general|name",
        },
        data = {
            transform = {},
            material = "/pkg/ant.resources/materials/simpletri.material",
            state = 0,
            quad_sphere = {
                num_trunk   = numtrunk,
                radius      = radius,
            },
            scene_entity = true,
            debug_mesh_bounding = true,
            name = name or "",
        }
    }
end

--{F, B, U, D, L, R}

local face_index<const> = {
    front = 0,
    back = 1,

    top = 2,
    bottom = 3,

    left = 4,
    right = 5,
}

local create_face_pt_op = {
    function (p2d, othercoord)
        p2d[3] = othercoord
        return p2d
    end,
    function (p2d, othercoord)
        p2d[3] = -othercoord
        return p2d
    end,
    function (p2d, othercoord)
        p2d[2], p2d[3] = othercoord, p2d[2]
        return p2d
    end,
    function (p2d, othercoord)
        p2d[2], p2d[3] = -othercoord, p2d[2]
        return p2d
    end,

    function (p2d, othercoord)
        p2d[1], p2d[2], p2d[3] = -othercoord, p2d[1], p2d[2]
        return p2d
    end,
    function (p2d, othercoord)
        p2d[1], p2d[2], p2d[3] = othercoord, p2d[1], p2d[2]
        return p2d
    end,
}

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

local quad_sphere_cube_len<const> = math.sqrt(2);
local hcl<const>   = quad_sphere_cube_len * 0.5;
local cube_tlf<const> = math3d.ref(math3d.vector(-hcl, hcl, hcl))
local cube_trf<const> = math3d.ref(math3d.vector( hcl, hcl, hcl))
local cube_tln<const> = math3d.ref(math3d.vector(-hcl, hcl,-hcl))
local cube_trn<const> = math3d.ref(math3d.vector( hcl, hcl,-hcl))
local cube_blf<const> = math3d.ref(math3d.vector(-hcl,-hcl, hcl))
local cube_brf<const> = math3d.ref(math3d.vector( hcl,-hcl, hcl))
local cube_bln<const> = math3d.ref(math3d.vector(-hcl,-hcl,-hcl))
local cube_brn<const> = math3d.ref(math3d.vector( hcl,-hcl,-hcl))


local function quad_sphere(num_trunk, radius)
	radius = radius or 1
    local trunk_vn = (num_trunk+1)
	local function create_face_vertices(pts, vertices, mirror_mask)
		local dl = math3d.mul(math3d.sub(pts[2], pts[1]), 1/num_trunk)
		local dt = math3d.mul(math3d.sub(pts[3], pts[1]), 1/num_trunk)
		
		local fn = trunk_vn * trunk_vn * 3

		local offset = #vertices
		for il=0, num_trunk do
			local lstart = math3d.muladd(dl, il, pts[1])
			local il_offset = offset + il * trunk_vn * 3
			for it=0, num_trunk do
				local v = math3d.tovalue(math3d.mul(radius, math3d.normalize(math3d.muladd(dt, it, lstart))))
				local off = il_offset+it*3
				for i=1, 3 do
					vertices[off+i]		= v[i]
					vertices[fn+off+i]	= mirror_mask[i] * v[i]
				end
			end
		end
	end

	local vertices = {}
	create_face_vertices({cube_tlf, cube_tln, cube_trf}, vertices, {1, -1, 1})	--top/bottom
	create_face_vertices({cube_blf, cube_bln, cube_tlf}, vertices, {-1, 1, 1})	--left/right
	create_face_vertices({cube_tln, cube_bln, cube_trn}, vertices, {1, 1, -1})	--front/back

	local fn = trunk_vn * trunk_vn
	local indices = create_face_quad_indices(num_trunk)
	local num = #indices
	for i=1, 5 do
		local offset = i * fn
		for j=1, num do
			indices[#indices+1] = offset + indices[j]
		end
	end

	return vertices, indices
	-- local face = {}
	-- local delta_t = math.pi / num_trunk
	-- local delta_f = math.pi * 2 / num_trunk
	-- for i=0, math.pi, delta_t do
	-- 	local s_i = math.sin(i)
	-- 	local c_i = math.cos(i)
	-- 	for j=0, 2 * math.pi, delta_f do
	-- 		face[#face+1] = {
	-- 			s_i * math.cos(j),
	-- 			s_i * math.sin(j),
	-- 			c_i
	-- 		}
	-- 	end
	-- end

end

local trunkid_class = {}
function trunkid_class.create(trunkid, qs)
    return setmetatable({
        trunkid = trunkid,
        qs = qs,
    }, {__index=trunkid_class})
end

--trunid:
--  tx: [0, 13], ty:[14, 27], f: [28, 31]
local function trunkid_face(trunkid)
    return trunkid >> 28
end

local function trunkid_index(trunkid)
    return (0x0fffffff & trunkid) >> 14, (0x00003fff & trunkid)
end

local function pack_trunkid(face, tx, ty)
    return (face << 28|ty << 14 |tx)
end

function trunkid_class:face()
    return trunkid_face(self.trunkid)
end

function trunkid_class:trunk_index_coord()
    return trunkid_index(self.trunkid)
end

function trunkid_class:unpack()
    local t = self.trunkid
    return trunkid_face(t), trunkid_index(t)
end

function trunkid_class:coord()
    local tix, tiy = self:trunk_index_coord()
    local offset = self.qs.proj_trunk_len * self.qs.num_trunk * 0.5
    return tix - offset, tiy - offset
end

function trunkid_class:coord_3d()
    local radius = self.qs.radius
    local face = self:face()
    local op = create_face_pt_op[face+1]
    local tx, ty = self:coord()
    return math3d.mul(radius, math3d.normalize(math3d.vector(op({tx, ty}, self.qs.cube_len * 0.5))))
end


--[[
    r:      raidus
    theta:  [0, pi/2]
    phi:    [0, 2*pi]
    x:      r*sin(theta)*cos(phi)
    y:      r*sin(theta)*sin(phi)
    z:      r*cos(theta)

    r:      sqrt(dot(p))
    theta:  arccos(z/r)
    phi:    arccos(x/(r*sin(theta)))
]]
function trunkid_class:to_sphereical_coord(xyzcoord)
    local nc = math3d.tovalue(math3d.mul(1/self.qs.radius, math3d.vector(xyzcoord)))
    local theta = math.acos(nc[3])
    local sintheta = math.sin(theta)
    local phi = math.acos(nc[1]/sintheta)
    return theta, phi
end

function trunkid_class:to_xyz(theta, phi)
    local sintheta, costheta = math.sin(theta), math.cos(theta)
    local sinphi, cosphi    = math.sin(phi), math.cos(phi)
    return math3d.mul(self.ps.raidus, math3d.vector(sintheta*cosphi, sintheta*sinphi, costheta))
end

function trunkid_class:proj_corners()
    local x, y = self:coord()
    local ptl = self.qs.proj_trunk_len
    return {
        {x, y},
        {x+ptl, y},
        {x, y+ptl},
        {x+ptl, y+ptl},
    }
end

function trunkid_class:corners_3d()
    local face      = self:face()
    local corners   = self:proj_corners()

    local face_pt_op= create_face_pt_op[face+1]
    local coord3    = self.qs.cube_len * 0.5
    for i=1, #corners do
        face_pt_op(corners[i], coord3)
    end
    return corners
end

function trunkid_class:position(x, y)
    local cx, cy = self:trunk_index_coord()
    local qs = self.qs
    local tu = qs.proj_trunk_unit
    local plen = qs.proj_trunk_len

    local offset = {cx * plen, cy * plen}

    local t = {offset[1] + x * tu, offset[2] + y * tu}
    local face = self:face()
    return create_face_pt_op[face+1](t, qs.radius)
end

local function tile_vertices(trunkid, qs)
    local radius    = qs.radius
    local tid       = trunkid_class.create(trunkid, qs)
    local corners   = tid:corners_3d()

    local h = math3d.sub(corners[2], corners[1])
    local v = math3d.sub(corners[3], corners[1])

    local vertices = {}
    local inv_tile_size = 1.0/tile_pre_trunk_line

    local hd = math3d.mul(h, inv_tile_size)
    local vd = math3d.mul(v, inv_tile_size)
    local aabb = math3d.aabb()
    for i=0, tile_pre_trunk_line do
        local sp = math3d.muladd(hd, i, corners[1])
        for j=0, tile_pre_trunk_line do
            local p = math3d.mul(radius, math3d.normalize(math3d.muladd(vd, j, sp)))
            aabb = math3d.aabb_append(aabb, p)
            local vp = math3d.tovalue(p)
            for ii=1, 3 do
                vertices[#vertices+1] = vp[ii]
            end
        end
    end
    return vertices, aabb
end

function iquad_sphere.trunk_position(eid, trunkid, x, y)
    local e = world[eid]
    local qs = e._quad_sphere
    return trunkid_class.create(trunkid, qs):position(x, y)
end


iquad_sphere.pack_trunkid = pack_trunkid

function iquad_sphere.unpack_trunkid(trunkid)
    return trunkid_face(trunkid), trunkid_index(trunkid)
end

function iquad_sphere.center_coord(eid, spherecial)
    local e = world[eid]
    local qs = e._quad_sphere
    local trunkid = qs.trunkid
    local tid = trunkid_class.create(trunkid, qs)
    local xyz = tid:coord_3d()
    if spherecial then
        return tid:to_sphereical_coord(xyz)
    end
    return xyz
end

local function which_face(pos)
    local x, y, z = pos[1], pos[2], pos[3]
    local ax, ay, az = math.abs(x), math.abs(y), math.abs(z)
    if ax > ay then
        if ax > az then
            return x > 0 and face_index.right or face_index.left, y, z
        end
    else
        if ay > az then
            return y > 0 and face_index.top or face_index.bottom, x, z
        end
    end

    return z > 0 and face_index.front or face_index.back, x, y
end

function iquad_sphere.trunk_index(eid, pos)
    local e = world[eid]
    local qs = e._quad_sphere

    local face, x, y = which_face(pos)

    local nt = qs.num_trunk
    local tl = qs.proj_trunk_len
    local trunk_coord = {x / tl, y / tl}

    local trunkid = face * qs.trunks_pre_face + trunk_coord[2] * nt + trunk_coord[1]
    local tile_coord_x, tile_coord_y = x - trunk_coord[1] * nt, y - trunk_coord[2]

    return trunkid, tile_coord_x, tile_coord_y
end

function iquad_sphere.set_trunkid(eid, trunkid)
    local e = world[eid]
    local qs = e._quad_sphere
    if qs.trunkid ~= trunkid then
        qs.trunkid = trunkid
        ientity_state.set_state(eid, "visible", true)
    end

    local vertices, aabb = tile_vertices(trunkid, qs)
    e._bounding.aabb.m = aabb
    local rc = e._rendercache
    rc.aabb = e._bounding.aabb

    local vb = rc.vb
    local poshandle = vb.handles[1]
    bgfx.update(poshandle, 0, bgfx.memory_buffer("fff", vertices), quad_sphere_vertex_layout.handle)
end

function iquad_sphere.add_line_grid(eid)
    local e = world[eid]
    local qs = e._quad_sphere
    local trunkid = qs.trunkid
    local vertices = tile_vertices(trunkid, qs)

    local mesh = ientity.create_mesh({"p3", vertices}, trunk_line_indices)
    return ientity.create_simple_render_entity(
        "quad_sphere_line",
        "/pkg/ant.resources/materials/line.material",
        mesh)
end

function iquad_sphere.tile_aabbs(eid)
    local e = world[eid]
    local qs = e._quad_sphere
    local trunkid = qs.trunkid
    local vertices = tile_vertices(trunkid, qs)

    local aabbs = {}
    for ih=1, tile_pre_trunk_line do
        local offset = (ih-1) * vertices_pre_tile_line
        for iv=1, tile_pre_trunk_line do
            local voff = (iv-1) * 3
            local idx = offset + voff + iv

            local aabb = math3d.aabb()
            aabbs[#aabbs+1] = math3d.aabb_append(aabb,
                math3d.vector(vertices[idx],            vertices[idx+1],        vertices[idx+2]),
                math3d.vector(vertices[idx+3],          vertices[idx+4],        vertices[idx+5]),
                math3d.vector(vertices[idx+offset],     vertices[idx+offset+1], vertices[idx+offset+2]),
                math3d.vector(vertices[idx+offset+3],   vertices[idx+offset+4], vertices[idx+offset+5])
            )
        end
    end

    return aabbs
end

local function tile_delta(qs)
    local corners = trunkid_class.create(qs.trunkid, qs):corners_3d()

    local h = math3d.sub(corners[2], corners[1])
    local v = math3d.sub(corners[3], corners[1])

    local inv_tile_size = 1.0/tile_pre_trunk_line

    return  math3d.mul(h, inv_tile_size),
            math3d.mul(v, inv_tile_size),
            corners[1]
end

function iquad_sphere.tile_aabb(eid, tilex, tiley)
    local e = world[eid]
    local qs = e._quad_sphere
    local trunkid = qs.trunkid
    if trunkid == nil then
        return
    end

    local hd, vd, basept = tile_delta(qs)

    local aabb = math3d.aabb()
    for _, coord in ipairs{
        {tilex-1,   tiley-1},
        {tilex,     tiley-1},
        {tilex-1,   tiley},
        {tilex,     tiley},
    } do
        local tileorigin_proj = math3d.muladd(vd, coord[2], math3d.muladd(hd, coord[1], basept))
        aabb = math3d.aabb_append(aabb, math3d.mul(qs.radius, math3d.normalize(tileorigin_proj)))
    end

    return aabb
end

function iquad_sphere.tile_center(eid, tilex, tiley)
    local e = world[eid]
    local qs = e._quad_sphere
    local trunkid = qs.trunkid
    if trunkid == nil then
        return
    end

    assert(tilex > 0 and tiley > 0)

    local hd, vd, basept = tile_delta(qs)

    local sp = math3d.add(math3d.muladd(hd, tilex-1, basept), math3d.mul(0.5, hd))
    return math3d.mul(qs.radius, math3d.normalize(
        math3d.add(
            math3d.muladd(vd, tiley-1, sp), 
            math3d.mul(0.5, vd)
        )
    ))
end

function iquad_sphere.focus_camera(eid, camreaeid, view_height, focus_pt)
    local e = world[eid]

    local qs = e._quad_sphere
    
    local camera_radius = view_height + qs.radius
    local viewdir = math3d.normalize(focus_pt)
    local camerapos = math3d.mul(viewdir, camera_radius)
    viewdir = math3d.inverse(viewdir)
    iom.lookto(camreaeid, camerapos, viewdir)
end