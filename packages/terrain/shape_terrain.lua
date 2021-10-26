local ecs   = ...
local world = ecs.world
local w     = world.w

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr

local fs        = require "filesystem"
local datalist  = require "datalist"
local bgfx      = require "bgfx"

local imesh     = ecs.import.interface "ant.asset|imesh"

local quad_ts = ecs.system "shape_terrain_system"

local function read_terrain_field(tf)
    if type(tf) == "string" then
        return datalist.parse(fs.open(fs.path(tf)):read "a")
    end

    return tf
end

local function is_power_of_2(n)
	if n ~= 0 then
		local l = math.log(n, 2)
		return math.ceil(l) == math.floor(l)
	end
end

local layout_name<const>    = declmgr.correct_layout "p3|n3|T3|c40niu|t20"
local layout                = declmgr.get(layout_name)
local memfmt<const>         = declmgr.vertex_desc_str(layout_name)

local packfmt<const> = "fffffffffIff"
local function add_cube(vb, origin, extent, color)
    local ox, oy, oz = table.unpack(origin)
    local nx, ny, nz = ox+extent[1], oy+extent[2], oz+extent[3]
    local v = {
        packfmt:pack(ox, oy, nz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 0.0), --3
        packfmt:pack(nx, oy, nz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 1.0), --2
        packfmt:pack(nx, oy, oz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 1.0), --1
        packfmt:pack(ox, oy, oz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 0.0), --0

        --top
        packfmt:pack(ox, ny, oz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 0.0), --4
        packfmt:pack(ox, ny, nz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 1.0), --5
        packfmt:pack(nx, ny, nz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 1.0), --6
        packfmt:pack(nx, ny, oz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 0.0), --7

        --left
        packfmt:pack(nx, oy, oz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 0.0), --1
        packfmt:pack(ox, ny, nz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 1.0), --5
        packfmt:pack(ox, ny, oz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 1.0), --4
        packfmt:pack(ox, oy, oz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 0.0), --0

        --right
        packfmt:pack(ox, oy, nz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 0.0), --3
        packfmt:pack(nx, ny, oz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 1.0), --7
        packfmt:pack(nx, ny, nz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 1.0), --6
        packfmt:pack(nx, oy, nz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 0.0), --2

        --front
        packfmt:pack(ox, oy, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 0.0, 0.0), --0
        packfmt:pack(ox, ny, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 0.0, 1.0), --4
        packfmt:pack(nx, ny, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 1.0, 1.0), --7
        packfmt:pack(ox, oy, nz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 1.0, 0.0), --3

        --back
        packfmt:pack(nx, oy, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 0.0, 0.0), --2
        packfmt:pack(nx, ny, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 0.0, 1.0), --6
        packfmt:pack(ox, ny, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 1.0, 1.0), --5
        packfmt:pack(nx, oy, oz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 1.0, 0.0), --1
    }

    vb[#vb+1] = table.concat(v, "")
end

--[[
     5-------6
    /       /|
   /       / |
  4-------7  2
  |       |  /
  |       | /
  0-------3
]]

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

local function to_mesh_buffer(vb)
    local vbbin = table.concat(vb, "")
    local numv = #vbbin // #memfmt
    local numi = (numv // NUM_QUAD_VERTICES) * 6 --6 for one quad 2 triangles and 1 triangle for 3 indices

    local numcube = numv // NUM_CUBE_VERTICES
    if numcube > MAX_CUBES then
        error(("index buffer for max cube is: %d, need: %d, try to make 'section_size' lower!"):format(MAX_CUBES, numcube))
    end

    return {
        vb = {
            start = 0,
            num = numv,
            {
                handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(vbbin), layout.handle),
            }
        },
        ib = {
            start = 0,
            num = numi,
            handle = cubeib_handle,
        }
    }
end

local function build_section_mesh(sectionsize, sectionidx, unit, cterrainfileds)
    local vb = {}
    for ih=1, sectionsize do
        for iw=1, sectionsize do
            local field = cterrainfileds:get_field(sectionidx, iw, ih)
            if field.type == "grass" or field.type == "dust" then
                local colors<const> = {
                    grass   = 0xff00ff00,
                    dust    = 0xff00ffff,
                }
                local x, z = cterrainfileds:get_offset(sectionidx)
                local h = field.height or 0
                local origin = {(iw-1+x)*unit, 0.0, (ih-1+z)*unit}
                local extent = {unit, h*unit, unit}
                add_cube(vb, origin, extent, colors[field.type])
            end
        end
    end

    if #vb > 0 then
        return to_mesh_buffer(vb)
    end
end

local function build_section_edge_mesh(sectionsize, sectionidx, unit, cterrainfileds)
    local vb = {}
    local color = cterrainfileds.edge.color
    for ih=1, sectionsize do
        for iw=1, sectionsize do
            local field = cterrainfileds:get_field(sectionidx, iw, ih)
            local edges = field.edges
            if edges then
                for k, edge in pairs(edges) do
                    add_cube(vb, edge.origin, edge.extent, color)
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

function cterrain_fields:build_edges()
    local tf = self.terrain_fields
    local w, h = self.width, self.height
    local unit = self.unit
    local thickness = self.edge.thickness
    
    for ih=1, h do
        for iw=1, w do
            local idx = (ih-1)*w+iw
            local f = tf[idx]
            local hh = f.height * 1.05 * unit
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
end

function quad_ts:entity_init()
    for e in w:select "INIT shape_terrain:in material:in reference:in" do
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
        local material = e.material

        local ctf = cterrain_fields.new(st)
        ctf:build_edges()

        for ih=1, st.section_height do
            for iw=1, st.section_width do
                local sectionidx = (ih-1) * st.section_width+iw
                
                local terrain_mesh = build_section_mesh(ss, sectionidx, unit, ctf)
                if terrain_mesh then
                    local ce = ecs.create_entity{
                        policy = {
                            "ant.scene|scene_object",
                            "ant.render|simplerender",
                            "ant.general|name",
                        },
                        data = {
                            scene = {
                                srt = {}
                            },
                            reference   = true,
                            simplemesh  = terrain_mesh,
                            material    = material,
                            state       = "visible|selectable",
                            name        = "section" .. sectionidx,
                            shape_terrain_drawer = true,
                        }
                    }

                    ecs.method.set_parent(ce, e.reference)
                end

                local edge_meshes = build_section_edge_mesh(ss, sectionidx, unit, ctf)
                if edge_meshes then
                    local ce = ecs.create_entity {
                        policy = {
                            "ant.scene|scene_object",
                            "ant.render|simplerender",
                            "ant.general|name",
                        },
                        data = {
                            scene = {
                                srt = {}
                            },
                            reference   = true,
                            material    = material,
                            simplemesh  = edge_meshes,
                            state       = "visible|selectable",
                            name        = "section_edge" .. sectionidx,
                            shape_terrain_edge_drawer = true,
                        }
                    }
                    ecs.method.set_parent(ce, e.reference)
                end
            end
        end
    end
end