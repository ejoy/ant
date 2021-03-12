local tile_pre_trunk_line<const> = 32
local vertices_pre_tile_line<const> = tile_pre_trunk_line+1
local visible_trunk_range<const> = 2
local vertices_per_trunk<const>     = vertices_pre_tile_line * vertices_pre_tile_line

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

    up      = 2,
    down    = 3,

    left    = 4,
    right   = 5,
}

local inscribed_cube_len<const>         = math.sqrt(3) * 2.0/3.0
local half_inscribed_cube_len<const>    = inscribed_cube_len * 0.5


local renderpkg = import_package "ant.render"
local declmgr = renderpkg.declmgr

local bgfx = require "bgfx"

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
    return {
        start = 0,
        num = #trunk_indices,
        handle = bgfx.create_index_buffer(bgfx.memory_buffer("w", trunk_indices))
    }
end

local c <const> = {
    inscribed_cube_len      = inscribed_cube_len,
    half_inscribed_cube_len = half_inscribed_cube_len,
    tile_pre_trunk_line     = tile_pre_trunk_line,
    inv_tile_pre_trunk_line = 1.0 / tile_pre_trunk_line,
    vertices_pre_tile_line  = vertices_pre_tile_line,
    vertices_per_trunk      = vertices_per_trunk,
    tiles_pre_trunk         = tile_pre_trunk_line * tile_pre_trunk_line,
    visible_trunk_range     = visible_trunk_range,
    trunk_ib = {
        indices             = trunk_indices,
        line_indices        = trunk_line_indices,
        buffer              = create_quad_sphere_trunk_ib(),
    },
    vb_layout = {
        declmgr.get "p3",
        declmgr.get "t20",
        declmgr.get "t21",
    },
    face_index              = face_index,
    _DEBUG                  = true,
}
return c