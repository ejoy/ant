local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local imaterial = ecs.import.interface "ant.asset|imaterial"
local irender   = ecs.import.interface "ant.render|irender"

local ipl = ecs.interface "ipolyline"

--[[
    vertex input desc:{
        vec3 pos;       // POSITION
        vec3 prev_pos;  // TEXCOORD0
        vec3 next_pos;  // TEXCOORD1
        vec2 uv;        // TEXCOORD2
        vec3 vertex_cfg;// TEXCOORD3, ==> [side, width, counters]
    };
    uniform:
    uint8 v_color[4];
    vec3  v_texcoord0;  //xy for uv, w for counter
]]

local declmgr           = require "vertexdecl_mgr"

local function create_strip_index_buffer(max_lines)
    local function create_ib_buffer(max_lines)
        local indices = {}
        local offset = 0
        for i=1, max_lines do
            indices[#indices+1] = offset + 0
            indices[#indices+1] = offset + 1
            indices[#indices+1] = offset + 2
    
            indices[#indices+1] = offset + 1
            indices[#indices+1] = offset + 3
            indices[#indices+1] = offset + 2
    
            offset = offset + 2
        end
    
        return bgfx.create_index_buffer(bgfx.memory_buffer("w", indices))
    end

    return {
        offset = 0,
        num_indices = max_lines,
        handle = create_ib_buffer(max_lines),
        alloc = function (self, numlines)
            local numindices<const> = numlines * 2 * 3
            local start = self.offset
        
            if start + numindices > self.num_indices then
                error(("not enough index buffer:%d, %d"):format(start+numindices, self.num_indices))
            end
        
            self.offset = start + numindices
        
            return {
                start = start,
                num = numindices,
                handle = self.handle,
            }
        end
    }
end

local strip_ib = create_strip_index_buffer(3072)

local function create_dynbuffer(max_vertices, desc)
    local function create_layout(desc)
        desc = declmgr.correct_layout(desc)
        local decl = declmgr.get(desc)
        local formatdesc = declmgr.vertex_desc_str(desc)
    
        return {
            desc    = desc,
            handle  = decl.handle,
            stride  = decl.stride,
            formatdesc = formatdesc
        }
    end

    local  layout = create_layout(desc)
    return {
        max_vertices    = max_vertices,
        offset          = 0,
        layout          = layout,
        handle          = bgfx.create_dynamic_vertex_buffer(max_vertices, layout.handle, "a"),
        vertices_num    = function (self, vertex_table)
            return #vertex_table / #self.layout.formatdesc
        end,
        alloc = function (self, num, vertices)
            local stride = layout.stride
            local start = self.offset / stride
            self.offset = self.offset + num * stride

            if self.offset > self.max_vertices * self.layout.stride then
                error(("not enough dynamic buffer:%d, %d"):format(self.offset, self.max_vertices * self.layout.stride))
            end
    
            local vb = {
                start = start,
                num = num,
                {handle = self.handle},
            }
            if vertices then
                self:update(vb, vertices)
            end
    
            return vb
        end,
        update = function(self, vb, vertices)
            local formatdesc = layout.formatdesc
            local h = self.handle
            assert((#vertices/#formatdesc) == vb.num and h == vb[1].handle)
            bgfx.update(h, vb.start, bgfx.memory_buffer(formatdesc, vertices))
        end,
        free = function(self, vb)
            --TODO
            assert(self.handle == vb[1])
        end,
    }
end

local dyn_stripline_vb = create_dynbuffer(1024, "p3|t20|t31|t32|t33")
local dyn_linelist_vb = create_dynbuffer(1024, "p3|t20|t31|t32")

local polylines = {}
local function generate_stripline_vertices(points)
    local vertex_elem_num<const> = #dyn_stripline_vb.layout.formatdesc
    local elem_offset = 0
    local vertices = {}
    local function fill_vertex(p, prev_p, next_p, u, v, side, width, counter)
        vertices[elem_offset+1],  vertices[elem_offset+2], vertices[elem_offset+3]   = p[1], p[2], p[3]
        vertices[elem_offset+4],  vertices[elem_offset+5]                            = u, v
        vertices[elem_offset+6],  vertices[elem_offset+7], vertices[elem_offset+8]   = side, width, counter
        vertices[elem_offset+9],  vertices[elem_offset+10],vertices[elem_offset+11]  = prev_p[1], prev_p[2], prev_p[3]
        vertices[elem_offset+12], vertices[elem_offset+13],vertices[elem_offset+14]  = next_p[1], next_p[2], next_p[3]
    
        elem_offset = elem_offset + vertex_elem_num
    end

    local numpoint = #points

    local delta<const> = 1 / (numpoint-1)
    local counter = 0
    for idx=1, numpoint do
        local p = points[idx]
        local prev_p = idx == 1         and p                or points[idx-1]
        local next_p = idx == numpoint  and points[numpoint] or points[idx+1]

        local tex_u<const> = counter
        fill_vertex(p, prev_p, next_p, tex_u, 0, 1, 1, counter)
        fill_vertex(p, prev_p, next_p, tex_u, 1, -1, 1, counter)

        counter = counter + delta
    end

    return vertices
end

local function add_polylines(polymesh, line_width, color, material)
    ecs.create_entity {
        policy = {
            "ant.render|simplerender",
            "ant.render|polyline",
            "ant.general|name",
        },
        data = {
            polyline = {
                width = line_width,
                color = color,
            },
            scene = {srt=mu.srt_obj()},
            simplemesh  = polymesh,
            material    = material,
            state       = 1,
            name        = "polyline",
        }
    }
end

local defcolor<const> = {1.0, 1.0, 1.0, 1.0}
function ipl.add_strip_lines(points, line_width, color, material)
    local numpoint = #points
    if numpoint < 2 then
        error(("strip line need at least 2 point:%d"):format(numpoint))
    end
    color = color or defcolor
    line_width = line_width or 1

    local vertices = generate_stripline_vertices(points)
    
    local numlines = numpoint-1

    local numvertex = dyn_stripline_vb:vertices_num(vertices)

    local polymesh = {
        ib = strip_ib:alloc(numlines),
        vb = dyn_stripline_vb:alloc(numvertex, vertices),
    }

    return add_polylines(polymesh, line_width, color, material or "/pkg/ant.resources/materials/polyline.material")
end

local function generate_linelist_vertices(points)
    local vertex_elem_num<const> = #dyn_linelist_vb.layout.formatdesc
    local elem_offset = 0
    local vertices = {}
    local function fill_vertex(p, d, u, v, side, width, counter)
        vertices[elem_offset+1],  vertices[elem_offset+2], vertices[elem_offset+3]   = p[1], p[2], p[3]
        vertices[elem_offset+4],  vertices[elem_offset+5]                            = u, v
        vertices[elem_offset+6],  vertices[elem_offset+7], vertices[elem_offset+8]   = side, width, counter
        vertices[elem_offset+9],  vertices[elem_offset+10], vertices[elem_offset+11] = d[1], d[2], d[3]
        elem_offset = elem_offset + vertex_elem_num
    end

    local numpoint = #points

    local function sub(p0, p1)
        return {p1[1]-p0[1], p1[2]-p0[2], p1[3]-p0[3]}
    end

    for idx=1, numpoint, 2 do
        local p0, p1 = points[idx], points[idx+1]
        local d0, d1 = sub(p1, p0), sub(p0, p1)
        local c0, c1 = (idx-1) / numpoint, idx / numpoint

        fill_vertex(p0, d0, 0, 0,  1, 1, c0)
        fill_vertex(p0, d0, 0, 1, -1, 1, c0)

        fill_vertex(p1, d1, 1, 0,  1, 1, c1)
        fill_vertex(p1, d1, 1, 1, -1, 1, c1)
    end

    return vertices
end

function ipl.add_linelist(pointlist, line_width, color, material)
    local numpoint = #pointlist
    if numpoint == 0 or numpoint % 2 ~= 0 then
        error(("privoided point for line's number must multiple of 2: %d"):format(numpoint))
    end

    color = color or defcolor
    line_width = line_width or 1

    local vertices = generate_linelist_vertices(pointlist)
    local numvertex = dyn_linelist_vb:vertices_num(vertices)

    local numlines = numpoint / 2

    local polymesh = {
        ib = {
            start = 0,
            num = numlines * 2 * 3,
            handle = irender.quad_ib(),
        },
        vb = dyn_linelist_vb:alloc(numvertex, vertices),
    }

    return add_polylines(polymesh, line_width, color, material or "/pkg/ant.resources/materials/polylinelist.material")
end

local pl_sys = ecs.system "polyline_system"

function pl_sys:entity_init()
    for e in w:select "INIT polyline:in polyline_mark?out" do
        e.polyline_mark = true
    end
end

function pl_sys:entity_ready()
    for e in w:select "polyline_mark polyline:in material_result:in" do
        local pl = e.polyline
        local properties = e.material_result.properties
        imaterial.set_property_directly(properties, "u_line_info", {pl.width, 0.0, 0.0, 0.0})
        imaterial.set_property_directly(properties, "u_color", pl.color)
    end
    w:clear "polyline_mark"
end