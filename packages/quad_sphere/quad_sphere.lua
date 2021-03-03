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

local ctrunkid = require "trunkid_class"

local tile_pre_trunk_line<const>    = 32
local inv_tile_pre_trunk_line<const> = 1.0 / tile_pre_trunk_line
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

local normalize_cube_vertices<const> = cube_vertices(1)

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
	create_face_vertices({normalize_cube_vertices.tlf, normalize_cube_vertices.tln, normalize_cube_vertices.trf}, vertices, {1, -1, 1})	--top/bottom
	create_face_vertices({normalize_cube_vertices.blf, normalize_cube_vertices.bln, normalize_cube_vertices.tlf}, vertices, {-1, 1, 1})	--left/right
	create_face_vertices({normalize_cube_vertices.tln, normalize_cube_vertices.bln, normalize_cube_vertices.trn}, vertices, {1, 1, -1})	--front/back

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

local qst = ecs.transform "quad_sphere_transform"
function qst.process_entity(e)
    local qs = e.quad_sphere
    local nt = qs.num_trunk
    local radius = qs.radius
    assert(nt > 0 and radius > 0)

    local cube_len = radius * inscribed_cube_len
    local proj_trunk_len = cube_len / qs.num_trunk

    local vertices = cube_vertices(radius)

    e._quad_sphere = {
        num_trunk       = nt,
        inv_num_trunk   = 1 / nt,
        num_trunk_point = nt + 1,
        trunks_pre_face = nt * nt,
        radius          = radius,
        cube_len        = cube_len,
        proj_trunk_len  = proj_trunk_len,
        proj_tile_len   = proj_trunk_len / tile_pre_trunk_line,
        inscribed_cube  = {
            vertices = vertices,
            {vertices.tln, vertices.trn, vertices.brn, vertices.bln}, --front
            {vertices.trf, vertices.tlf, vertices.blf, vertices.brf}, --back

            {vertices.tlf, vertices.trf, vertices.trn, vertices.tln}, --up
            {vertices.bln, vertices.brn, vertices.brf, vertices.blf}, --down

            {vertices.tlf, vertices.tln, vertices.bln, vertices.blf}, --left
            {vertices.trn, vertices.trf, vertices.brf, vertices.brn}, --right
        }
    }
end

function iquad_sphere.create(name, numtrunk, radius)
    --local verties, indices = geo.quad_sphere(numtrunk, radius)
    return world:create_entity {
        policy = {
            "ant.quad_sphere|quad_sphere",
            --"ant.render|debug_mesh_bounding",
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
            --debug_mesh_bounding = true,
            name = name or "",
        }
    }
end

local function tile_vertices(trunkid, qs)
    local radius    = qs.radius
    local hd, vd, basept = ctrunkid(trunkid, qs):tile_delta(inv_tile_pre_trunk_line)

    local vertices = {}
    local aabb = math3d.aabb()
    for vp in ctrunkid.iter_point(tile_pre_trunk_line, vd, basept) do
        for p in ctrunkid.iter_point(tile_pre_trunk_line, hd, vp) do
            local sp = ctrunkid.surface_point(radius, p)
            aabb = math3d.aabb_append(aabb, sp)
            local v = math3d.tovalue(sp)
            vertices[#vertices+1] = v[1]
            vertices[#vertices+1] = v[2]
            vertices[#vertices+1] = v[3]
        end
    end
    return vertices, aabb
end

-- normal num == tile num, not vertices normal
local function tile_normals(trunkid, qs)
    local radius    = qs.radius
    local tid       = ctrunkid(trunkid, qs)
    local corners   = tid:proj_corners_3d()


end

function iquad_sphere.trunk_position(eid, trunkid, x, y)
    local e = world[eid]
    local qs = e._quad_sphere
    return ctrunkid(trunkid, qs):position(x, y)
end


iquad_sphere.pack_trunkid = ctrunkid.pack_trunkid

function iquad_sphere.unpack_trunkid(trunkid)
    return ctrunkid.trunkid_face(trunkid), ctrunkid.trunkid_index(trunkid)
end

function iquad_sphere.center_coord(eid, spherecial)
    local e = world[eid]
    local qs = e._quad_sphere
    local trunkid = qs.trunkid
    local tid = ctrunkid(trunkid, qs)
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

function iquad_sphere.add_inscribed_cube(eid, color)
    local e = world[eid]
    local qs = e._quad_sphere
    local vertices = {}
    local function to_v(...)
        for idx=1, select('#', ...) do
            local v = select(idx, ...)
            local vv = math3d.tovalue(v)
            vertices[#vertices+1] = vv[1]
            vertices[#vertices+1] = vv[2]
            vertices[#vertices+1] = vv[3]
        end
    end
    local v = qs.inscribed_cube.vertices
    to_v(   v.tlf, v.trf, v.trn, v.tln,
            v.blf, v.brf, v.brn, v.bln)
    local indices = {
        0, 1, 1, 2, 2, 3, 3, 0,
        4, 5, 5, 6, 6, 7, 7, 4,

        0, 4, 1, 5, 2, 6, 3, 7,
    }

    local mesh = ientity.create_mesh({"p3", vertices}, indices)
    local eid = ientity.create_simple_render_entity(
        "quad_sphere_line",
        "/pkg/ant.resources/materials/line_color.material",
        mesh)

    if color then
        local imaterial = world:interface "ant.asset|imaterial"
        imaterial.set_property(eid, "u_color", color)
    end
end

function iquad_sphere.add_solid_angle_entity(eid, color)
    local e         = world[eid]
    local qs        = e._quad_sphere

    local tid       = ctrunkid(qs.trunkid, qs)
    local corners   = tid:proj_corners_3d()
    local vertices = {}
    for _, c in ipairs(corners) do
        local v = math3d.tovalue(c)
        vertices[#vertices+1] = v[1]
        vertices[#vertices+1] = v[2]
        vertices[#vertices+1] = v[3]
    end
    local indices = {0, 1, 2, 2, 3, 0}
    local mesh = ientity.create_mesh({"p3", vertices}, indices)
    local plane_eid = ientity.create_simple_render_entity(
        "proj_corners",
        "/pkg/ant.resources/materials/simpletri.material",
        mesh)

    vertices[#vertices+1] = 0
    vertices[#vertices+1] = 0
    vertices[#vertices+1] = 0
    local proj_cube_indices = {5, 0, 5, 1, 5, 2, 5, 3, 5, 4}
    local linemesh = ientity.create_mesh({"p3", vertices}, proj_cube_indices)

    local plane_line_eid = ientity.create_simple_render_entity(
        "proj_corners_line",
        "/pkg/ant.resources/materials/line_color.material",
        linemesh)

    local curve_vertices = {}
    for i=1, 4*3 do
        curve_vertices[i] = vertices[i]
    end
    local corners3d = tid:corners_3d()
    for _, c in ipairs(corners3d) do
        local v = math3d.tovalue(c)
        curve_vertices[#curve_vertices+1] = v[1]
        curve_vertices[#curve_vertices+1] = v[2]
        curve_vertices[#curve_vertices+1] = v[3]
    end

    local curve_line_indices = {
        0, 4, 1, 5, 2, 6, 3, 7
    }

    local curvemesh = ientity.create_mesh({"p3", curve_vertices}, curve_line_indices)

    local curved_eid = ientity.create_simple_render_entity(
        "curved_line",
        "/pkg/ant.resources/materials/line_color.material",
        curvemesh)
    
    if color then
        local imaterial = world:interface "ant.asset|imaterial"
        imaterial.set_property(plane_eid, "u_color", color)
        imaterial.set_property(plane_line_eid, "u_color", color)
        imaterial.set_property(curved_eid, "u_color", color)
    end

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

function iquad_sphere.tile_aabb(eid, tilex, tiley)
    local e = world[eid]
    local qs = e._quad_sphere
    local trunkid = qs.trunkid
    if trunkid == nil then
        return
    end

    local hd, vd, basept = ctrunkid(trunkid, qs):tile_delta(inv_tile_pre_trunk_line)

    local aabb = math3d.aabb()
    for _, coord in ipairs{
        {tilex-1,   tiley-1},
        {tilex,     tiley-1},
        {tilex-1,   tiley},
        {tilex,     tiley},
    } do
        local tileorigin_proj = ctrunkid.quad_position(hd, vd, coord[1], coord[2], basept)
        aabb = math3d.aabb_append(aabb, ctrunkid.surface_point(qs.radius, tileorigin_proj))
    end

    return aabb
end

function iquad_sphere.tile_center(eid, tilex, tiley)
    local e = world[eid]
    local qs = e._quad_sphere
    local trunkid = qs.trunkid

    local hd, vd, basept = ctrunkid(trunkid, qs):tile_delta(inv_tile_pre_trunk_line)

    local p = ctrunkid.quad_position(hd, vd, tilex-1, tiley-1, basept)
    return ctrunkid.quad_position(hd, vd, 0.5, 0.5, p)
end

function iquad_sphere.tile_normals(eid)
    local e = world[eid]
    local qs = e._quad_sphere
    local trunkid = qs.trunkid
    local hd, vd, basept = ctrunkid(trunkid, qs):tile_delta(inv_tile_pre_trunk_line)
    local radius = qs.radius

    local normals = {}
    local ip = ctrunkid.iter_point
    for vp in ip(tile_pre_trunk_line-1, vd, basept) do
        for p in ip(tile_pre_trunk_line-1, hd, vp) do
            normals[#normals+1] = ctrunkid.surface_point(radius, ctrunkid.quad_position(hd, vd, 0.5, 0.5, p))
        end
    end
    return normals
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