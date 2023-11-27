local ecs   = ...
local world = ecs.world
local w     = world.w

local renderpkg = import_package "ant.render"
local layoutmgr = renderpkg.layoutmgr

local datalist  = require "datalist"
local bgfx      = require "bgfx"
local math3d    = require "math3d"
local aio       = import_package "ant.io"

local shape_types<const> = {
    "none", "grass", "dust",
}


local shape_ts = ecs.system "cube_shape_terrain_system"

local function read_terrain_field(tf)
    if type(tf) == "string" then
        return datalist.parse(aio.readall(tf))
    end
    return tf
end

local function is_power_of_2(n)
	if n ~= 0 then
		local l = math.log(n, 2)
		return math.ceil(l) == math.floor(l)
	end
end

local layout_name<const>    = layoutmgr.correct_layout "p3|n3|T3|c40niu|t20"
local layout                = layoutmgr.get(layout_name)

--[[
     5-------6
    /       /|
   /       / |
  4-------7  2
  |       |  /
  |       | /
  0-------3
]]
local packfmt<const> = "fffffffffIff"
local function add_cube(vb, origin, extent, color, uv0, uv1)
    local ox, oy, oz = table.unpack(origin)
    local nx, ny, nz = ox+extent[1], oy+extent[2], oz+extent[3]
    local u00, v00, u01, v01 = table.unpack(uv0)
    local u10, v10, u11, v11 = table.unpack(uv1)
    local v = {
        --bottom
        packfmt:pack(nx, oy, oz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, u00, v01), --3
        packfmt:pack(nx, oy, nz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, u00, v00), --2
        packfmt:pack(ox, oy, nz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, u01, v00), --1
        packfmt:pack(ox, oy, oz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, u01, v01), --0

        --top
        packfmt:pack(ox, ny, oz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, u00, v01), --4
        packfmt:pack(ox, ny, nz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, u00, v00), --5
        packfmt:pack(nx, ny, nz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, u01, v00), --6
        packfmt:pack(nx, ny, oz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, u01, v01), --7

        --left
        packfmt:pack(ox, oy, nz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, u10, v11), --1
        packfmt:pack(ox, ny, nz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, u10, v10), --5
        packfmt:pack(ox, ny, oz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, u11, v10), --4
        packfmt:pack(ox, oy, oz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, u11, v11), --0

        --right
        packfmt:pack(nx, oy, oz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, u10, v11), --3
        packfmt:pack(nx, ny, oz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, u10, v10), --7
        packfmt:pack(nx, ny, nz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, u11, v10), --6
        packfmt:pack(nx, oy, nz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, u11, v11), --2

        --front
        packfmt:pack(ox, oy, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, u10, v11), --0
        packfmt:pack(ox, ny, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, u10, v10), --4
        packfmt:pack(nx, ny, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, u11, v10), --7
        packfmt:pack(nx, oy, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, u11, v11), --3

        --back
        packfmt:pack(nx, oy, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, u10, v11), --2
        packfmt:pack(nx, ny, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, u10, v10), --6
        packfmt:pack(ox, ny, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, u11, v10), --5
        packfmt:pack(ox, oy, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, u11, v11), --1
    }

    vb[#vb+1] = table.concat(v, "")
end

local default_quad_ib<const> = {
    0, 1, 2,
    2, 3, 0,
}

local function add_quad_ib(ib, offset)
    for i=1, #default_quad_ib do
        ib[#ib+1] = default_quad_ib[i] + offset
    end
end

local default_cube_ib = {}
for i=0, 5 do
    add_quad_ib(default_cube_ib, 4*i)
end

--build ib
local cubeib_handle
local MAX_CUBES<const> = 256*256
local NUM_QUAD_VERTICES<const> = 4
local NUM_CUBE_FACES<const> = 6
local NUM_CUBE_VERTICES = NUM_QUAD_VERTICES * NUM_CUBE_FACES
do
    local cubeib = {}
    for i=1, #default_cube_ib do
        cubeib[i] = default_cube_ib[i]
    end
    local fmt<const> = ('I'):rep(#cubeib)
    local offset<const> = NUM_CUBE_VERTICES    --24 = 4 * 6, 4 vertices pre face and 6 faces

    local s = #fmt * 4  -- 4 for sizeof(uint32)
    -- here, section size maybe same as terrain size, max size is 256*256
    local m = bgfx.memory_buffer(s*MAX_CUBES)
    for i=1, MAX_CUBES do
        local mo = s*(i-1)+1
        m[mo] = fmt:pack(table.unpack(cubeib))
        for ii=1, #cubeib do
            cubeib[ii]  = cubeib[ii] + offset
        end
    end
    cubeib_handle = bgfx.create_index_buffer(m, "d")
end

local function to_mesh_buffer(vb, aabb)
    local vbbin = table.concat(vb, "")
    local numv = #vbbin // layout.stride
    local numi = (numv // NUM_QUAD_VERTICES) * 6 --6 for one quad 2 triangles and 1 triangle for 3 indices

    local numcube = numv // NUM_CUBE_VERTICES
    if numcube > MAX_CUBES then
        error(("index buffer for max cube is: %d, need: %d, try to make 'section_size' lower!"):format(MAX_CUBES, numcube))
    end

    return {
        bounding = {aabb = aabb and math3d.ref(aabb) or nil},
        vb = {
            start = 0,
            num = numv,
            handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(vbbin), layout.handle),
        },
        ib = {
            start = 0,
            num = numi,
            handle = cubeib_handle,
        }
    }
end

local DEFAULT_colors<const> = {
    grass   = 0xffffffff,
    dust    = 0xffffffff,
    edge    = 0xffffffff,
}

local DEFAULT_color<const> = 0xffffffff

-- 2x4 tiles for all texture
local NUM_UV_ROW<const>, NUM_UV_COL<const> = 2, 4
local UV_TILES = {}
do
    local row_step<const>, col_step<const> = 1.0/NUM_UV_ROW, 1.0/NUM_UV_COL
    for ir=1, NUM_UV_ROW do
        local v0, v1 = (ir-1)*row_step, ir*row_step
        for ic=1, NUM_UV_COL do
            local u0, u1 = (ic-1)*col_step, ic*col_step
            UV_TILES[#UV_TILES+1] = {u0, v0, u1, v1}
        end
    end
end

local function find_shape_uv(st, height, minheight, maxheight)
    local row
    if st == "grass" then
        row = 0
    elseif st == "dust" then
        row = 1
    else
        error("invalid shape type: " .. st)
    end

    local col = 0
    if maxheight > minheight then
        local s = (maxheight-minheight)/NUM_UV_COL
        for h=minheight, maxheight, s do
            if h<=height and height<=(h+s+10e-8) then
                break
            end
            col = col + 1
        end
    end

    if col >= NUM_UV_COL then
        error(("invalid height:%f, [%f, %f]"):format(height, minheight, maxheight))
    end

    local idx = row*NUM_UV_COL+col+1
    return assert(UV_TILES[idx])
end

local DEFAULT_SHAPE_SECOND_UV<const> = UV_TILES[4]  -- 3 for dust first uv

local function gen_shape_second_uv(height, unit)
    local uv = {
        table.unpack(DEFAULT_SHAPE_SECOND_UV)
    }

    local h = height / unit
    uv[2] = uv[4] - h
    return uv
end

local function build_section_mesh(sectionsize, sectionidx, unit, cterrainfileds)
    local vb = {}
    local minh, maxh = cterrainfileds.minheight, cterrainfileds.maxheight
    local min_y, max_y = math.maxinteger, -math.maxinteger
    for ih=1, sectionsize do
        for iw=1, sectionsize do
            local field = cterrainfileds:get_field(sectionidx, iw, ih)
            local h = assert(field.height) * unit
            min_y, max_y = math.min(h, min_y), math.max(h, max_y)
            if field.type == "grass" or field.type == "dust" then
                local x, z = cterrainfileds:get_offset(sectionidx)
                local origin = {(iw-1+x)*unit, 0.0, (ih-1+z)*unit}
                local extent = {unit, h, unit}
                local uv0 = find_shape_uv(field.type, h, minh, maxh)
                add_cube(vb, origin, extent, DEFAULT_color, uv0, gen_shape_second_uv(h, unit))
            end
        end
    end

    if #vb > 0 then
        local min_x, min_z = cterrainfileds:get_offset(sectionidx)
        local max_x, max_z = (min_x + sectionsize) * unit, (min_z + sectionsize) * unit
        return to_mesh_buffer(vb, math3d.aabb(math3d.vector(min_x, min_y, min_z), math3d.vector(max_x, max_y, max_z)))
    end
end

local DEFAULT_EDGE_UV<const> = {0.0, 0.0, 1.0, 1.0}

local function build_section_edge_mesh(sectionsize, sectionidx, unit, cterrainfileds)
    local vb = {}
    local color = cterrainfileds.edge.color
    local h = cterrainfileds.maxheight
    for ih=1, sectionsize do
        for iw=1, sectionsize do
            local field = cterrainfileds:get_field(sectionidx, iw, ih)
            local edges = field.edges
            if edges then
                for k, edge in pairs(edges) do
                    local e = edge.extent
                    local extent = {e[1], h, e[3]}
                    add_cube(vb, edge.origin, extent, color, DEFAULT_EDGE_UV, DEFAULT_EDGE_UV)
                end
            end
        end
    end

    if #vb > 0 then
        return to_mesh_buffer(vb)
    end
end

local cterrain_fields = {}

function cterrain_fields.new(st)
    return setmetatable(st, {__index=cterrain_fields})
end

--[[
    field:
        type: [none, grass, dust]
        height: 0.0
        edges: {left, right, top, bottom}
]]
function cterrain_fields:get_field(sidx, iw, ih)
    local ish = (sidx-1) // self.section_width
    local isw = (sidx-1) % self.section_width

    local offset = (ish * self.section_size+ih-1) * self.width +
                    isw * self.section_size + iw

    return self.terrain_fields[offset]
end

function cterrain_fields:get_offset(sidx)
    local ish = (sidx-1) // self.section_width
    local isw = (sidx-1) % self.section_width
    return isw * self.section_size, ish * self.section_size
end

function cterrain_fields:init()
    local tf = self.terrain_fields
    local w, h = self.width, self.height
    local unit = self.unit
    local thickness = self.edge.thickness * unit
    local minheight, maxheight = math.maxinteger, -math.maxinteger

    for ih=1, h do
        for iw=1, w do
            local idx = (ih-1)*w+iw
            local f = tf[idx]
            local hh = f.height * 1.05 * unit
            minheight = math.min(f.height*unit, minheight)
            maxheight = math.max(f.height*unit, maxheight)
            if f.type ~= "none" then
                local function is_empty_elem(iiw, iih)
                    if iiw == 0 or iih == 0 or iiw == w+1 or iih == h+1 then
                        return true
                    end

                    local iidx = (iih-1)*w+iiw
                    return assert(tf[iidx]).type == "none"
                end
                local edges = {}
                if is_empty_elem(iw-1, ih) then
                    local len = unit + 2 * thickness
                    local origin = {(iw-1)*unit-thickness, 0.0, (ih-1)*unit-thickness}
                    if not is_empty_elem(iw-1, ih+1) then
                        len = len - thickness
                    end
                    if not is_empty_elem(iw-1, ih-1) then
                        len = len - thickness
                        origin[3] = origin[3] + thickness
                    end
                    edges.left = {
                        origin = origin,
                        extent = {thickness, hh, len},
                    }
                end

                if is_empty_elem(iw+1, ih) then
                    local len = unit+2*thickness
                    local origin = {iw*unit, 0.0, (ih-1)*unit-thickness}
                    if not is_empty_elem(iw+1, ih+1) then
                        len = len - thickness
                    end
                    if not is_empty_elem(iw+1, ih-1) then
                        len = len - thickness
                        origin[3] = origin[3] + thickness 
                    end
                    edges.right = {
                        origin = origin,
                        extent = {thickness, hh, len}
                    }
                end

                --top
                if is_empty_elem(iw, ih+1) then
                    local len = unit+2*thickness
                    local origin = {(iw-1)*unit-thickness, 0.0, ih*unit}
                    if not is_empty_elem(iw-1, ih+1) then
                        len = len - thickness
                        origin[1] = origin[1] + thickness 
                    end
                    if not is_empty_elem(iw+1, ih+1) then
                        len = len - thickness
                    end
                    edges.top = {
                        origin = origin,
                        extent = {len, hh, thickness}
                    }
                end
                if is_empty_elem(iw, ih-1) then
                    local len = unit+2*thickness
                    local origin = {(iw-1)*unit-thickness, 0.0, (ih-1)*unit-thickness}
                    if not is_empty_elem(iw-1, ih-1) then
                        len = len - thickness
                        origin[1] = origin[1] + thickness 
                    end
                    if not is_empty_elem(iw+1, ih-1) then
                        len = len - thickness
                    end
                    edges.bottom = {
                        origin = origin,
                        extent = {len, hh, thickness}
                    }
                end

                f.edges = edges
            end
        end
    end

    self.minheight, self.maxheight = minheight, maxheight
end

local function calc_edge_aabb(aabb, thickness)
    local center, extents = math3d.aabb_center_extents(aabb)
    extents = math3d.add(extents, math3d.vector(thickness, thickness, thickness))
    return math3d.aabb(math3d.sub(center, extents), math3d.add(center, extents))
end

function shape_ts:entity_init()
    for e in w:select "INIT shape_terrain:in eid:in" do
        local st = e.shape_terrain

        if st.terrain_fields == nil then
            error "need define terrain_field, it should be file or table"
        end
        st.terrain_fields = read_terrain_field(st.terrain_fields)

        local width, height = st.width, st.height
        if width * height ~= #st.terrain_fields then
            error(("height_fields data is not equal 'width' and 'height':%d, %d"):format(width, height))
        end

        if not (is_power_of_2(width) and is_power_of_2(height)) then
            error(("one of the 'width' or 'heigth' is not power of 2"):format(width, height))
        end

        local ss = st.section_size
        if not is_power_of_2(ss) then
            error(("'section_size':%d, is not power of 2"):format(ss))
        end

        if ss == 0 or ss > width or ss > height then
            error(("invalid 'section_size':%d, larger than 'width' or 'height' or it is 0: %d, %d"):format(ss, width, height))
        end

        st.section_width, st.section_height = width // ss, height // ss
        st.num_section = st.section_width * st.section_height

        local unit = st.unit
        local materials = e.materials
        local shapematerial, edgematerial = materials.shape, materials.edge

        local ctf = cterrain_fields.new(st)
        ctf:init()

        for ih=1, st.section_height do
            for iw=1, st.section_width do
                local sectionidx = (ih-1) * st.section_width+iw
                
                local terrain_mesh = build_section_mesh(ss, sectionidx, unit, ctf)
                if terrain_mesh then
                    local eid; eid = world:create_entity{
                        policy = {
                            "ant.scene|scene_object",
                            "ant.render|simplerender",
                        },
                        data = {
                            scene = {
                                parent = e.eid,
                            },
                            simplemesh  = terrain_mesh,
                            material    = shapematerial,
                            visible_state= "main_view|selectable",
                            shape_terrain_drawer = true,
                            on_ready = function()
                                world:pub {"shape_terrain", "on_ready", eid, e.eid}
                            end,
                        },
                    }
                end

                local edge_meshes = build_section_edge_mesh(ss, sectionidx, unit, ctf)
                if edge_meshes then
                    edge_meshes.bounding = {aabb = math3d.ref(calc_edge_aabb(terrain_mesh.bounding.aabb, ctf.edge.thickness * unit))}
                    local eid; eid = world:create_entity {
                        policy = {
                            "ant.scene|scene_object",
                            "ant.render|simplerender",
                        },
                        data = {
                            scene = {
                                parent = e.eid,
                            },
                            material    = edgematerial,
                            simplemesh  = edge_meshes,
                            visible_state= "main_view|selectable",
                            shape_terrain_edge_drawer = true,
                            on_ready = function()
                                world:pub {"shape_terrain", "on_ready", eid, e.eid}
                            end,
                        },
                    }
                end
            end
        end
    end
end
