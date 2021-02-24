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

local tile_pre_trunk_line<const>    = 32
local vertices_pre_tile_line<const> = tile_pre_trunk_line+1
local vertices_per_trunk<const>     = vertices_pre_tile_line * vertices_pre_tile_line
local tiles_pre_trunk<const>        = tile_pre_trunk_line * tile_pre_trunk_line

--[[
    quad indices
    1 ----- 2
    |       |
    |       |
    0 ----- 3
]]

local function create_face_quad_indices(quadnum)
    local indices = {}
    local vertex_num = quadnum+1
    for i=0, quadnum-1 do
        local is = i * vertex_num
        local is_n = (i+1) * vertex_num
        for j=0, quadnum-1 do
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

local qsmt = ecs.transform "quad_sphere_mesh_transform"
function qsmt.process_entity(e)
    local qs  = e.quad_sphere
    local vtr = qs.visible_trunk_range

    local numtrunk = vtr * vtr
    local rc = e._rendercache
    
    local numvertices = numtrunk * vertices_per_trunk   --duplicate vertices on trunk edge
    rc.vb = {
        start = 0,
        num = numvertices,
        handles = {
            bgfx.create_dynamic_vertex_buffer(numvertices, declmgr.get "p3", "a"),
        }
    }

    assert(numvertices < 65535, "too many vertices")

    local numindices = numtrunk * tiles_pre_trunk * 6
    rc.ib = {
        start = 0,
        num = numindices,
        handle = bgfx.create_index_buffer(bgfx.memory_buffer("w", create_face_quad_indices))
    }
end

local qst = ecs.transform "quad_sphere_transform"
function qst.process_entity(e)
    local qs = e.quad_sphere
    local tn = qs.trunk_num
    local radius = qs.radius
    assert(tn > 0 and radius > 0)

    local cube_len = radius * math.sqrt(2)
    local proj_trunk_len = cube_len / qs.trunk_num
    e._quad_sphere = {
        cube_len    = cube_len,
        proj_trunk_len  = proj_trunk_len,
        proj_trunk_unit = proj_trunk_len / tile_pre_trunk_line
    }
end

function iquad_sphere.create(numtrunk, radius, name)
    --local verties, indices = geo.quad_sphere(numtrunk, radius)
    return world:create_entity {
        policy = {
            "ant.quad_sphere|quad_sphere",
            "ant.render|render",
            "ant.general|name",
        },
        data = {
            transform = {},
            material = "/pkg/ant.resources/materials/simpletri.material",
            mesh = {},
            state = 0,
            quad_sphere = {
                num_trunk   = numtrunk,
                radius      = radius,
                visible_trunk_range = 4,
            },
            scene_entity = true,
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
    function (p, radius)
        return {p[1], p[2], radius}
    end,
    function (p, radius)
        return {p[1], p[2], -radius}
    end,
    function (p, radius)
        return {p[1], radius, p[2]}
    end,
    function (p, radius)
        return {p[1], -radius, p[2]}
    end,

    function (p, radius)
        return {-radius, p[1], p[2]}
    end,
    function (p, radius)
        return {radius, p[1], p[2]}
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


local function quad_sphere(trunk_num, radius)
	radius = radius or 1
    local trunk_vn = (trunk_num+1)
	local function create_face_vertices(pts, vertices, mirror_mask)
		local dl = math3d.mul(math3d.sub(pts[2], pts[1]), 1/trunk_num)
		local dt = math3d.mul(math3d.sub(pts[3], pts[1]), 1/trunk_num)
		
		local fn = trunk_vn * trunk_vn * 3

		local offset = #vertices
		for il=0, trunk_num do
			local lstart = math3d.muladd(dl, il, pts[1])
			local il_offset = offset + il * trunk_vn * 3
			for it=0, trunk_num do
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
	local indices = create_face_quad_indices(trunk_num)
	local num = #indices
	for i=1, 5 do
		local offset = i * fn
		for j=1, num do
			indices[#indices+1] = offset + indices[j]
		end
	end

	return vertices, indices
	-- local face = {}
	-- local delta_t = math.pi / trunk_num
	-- local delta_f = math.pi * 2 / trunk_num
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

local function trunk_corner_vertices(trunk_num, radius, trunkid)
    --TODO: we need cache using trunk_num/trunkid
    local tn_pf = trunk_num * trunk_num
    local face = trunkid / tn_pf
    local trunk_idx = trunkid % tn_pf
    local trunk_coord_x, trunk_coord_y = trunk_idx % trunk_num, trunk_idx / trunk_num
    local face_pt_op = create_face_pt_op[face]
    return {
        face_pt_op({trunk_coord_x,  trunk_coord_y},     radius),
        face_pt_op({trunk_coord_x+1,trunk_coord_y},     radius),
        face_pt_op({trunk_coord_x,  trunk_coord_y+1},   radius),
        face_pt_op({trunk_coord_x+1,trunk_coord_y+1},   radius),
    }
end

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

local function tile_vertices(trunk_corners)
    local h = trunk_corners[2] - trunk_corners[1]
    local v = trunk_corners[3] - trunk_corners[1]

    local vertices = {}
    local inv_tile_size = 1.0/tile_pre_trunk_line

    local hd = h * inv_tile_size
    local vd = v * inv_tile_size
    for i=0, tile_pre_trunk_line do
        local sp = math3d.muladd(hd, trunk_corners[1])
        for j=0, tile_pre_trunk_line do
            local vp = math3d.tovalue(math3d.normalize(math3d.muladd(vd, sp)))
            for ii=1, 3 do
                vertices[#vertices+ii] = vp[ii]
            end
        end
    end
    return vertices
end

function iquad_sphere.trunk_position(eid, trunkid, x, y)
    local e = world[eid]
    local tn = e.quad_sphere.trunk_num
    local trunk_pre_face = (tn * tn)
    local face = trunkid / trunk_pre_face
    local trunkidx = trunkid % trunk_pre_face
    local trunk_coord = {
        trunkidx % tn, trunkidx / tn
    }

    local tu = e._quad_sphere.proj_trunk_unit
    local plen = e._quad_sphere.proj_trunk_len

    local offset = {trunk_coord[1] * plen, trunk_coord[2] * plen}

    local t = {offset[1] + x * tu, offset[2] + y * tu}

    return create_face_pt_op[face](t)
end

local function which_face(pos)
    local x, y, z = pos[1], pos[2], pos[3]
    local ax, ay, az = math.abs(x), math.abs[y], math.abs(z)
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

    local tn = e.quad_sphere.trunk_num
    local trunk_pre_face = (tn * tn)

    local tl = qs.proj_trunk_len
    local trunk_coord = {x / tl, y / tl}
    local trunkid = face * trunk_pre_face + trunk_coord[2] * tn + trunk_coord[1]
    local tile_coord_x, tile_coord_y = x - trunk_coord[1] * tn, y - trunk_coord[2]

    return trunkid, tile_coord_x, tile_coord_y
end

function iquad_sphere.set_trunkid(eid, trunkid)
    local e = world[eid]
    local qs = e.quad_sphere.radius

    local rt_qs = e._quad_sphere
    if rt_qs.trunkid == nil then
        rt_qs.trunkid = trunkid
        ientity_state.set_state(eid, "visible", true)
    end

    local trunk_vertices = trunk_corner_vertices(qs.trunk_num, qs.radius, trunkid)
    local vertices = tile_vertices(trunk_vertices)
    
    local vb = e._rendercache.vb
    local poshandle = vb.handles[1]
    bgfx.update(poshandle, 0, bgfx.memory_buffer("p3", vertices))
end