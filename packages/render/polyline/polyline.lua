local ecs = ...
local world = ecs.world
local bgfx = require "bgfx"
local imaterial = world:interface "ant.asset|imaterial"
local irender   = world:interface "ant.render|irender"
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

local function create_ib_buffer(max_lines)
    local indices = {}
    local numindices<const> = max_lines * 2 * 3

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

    return {
        offset = 0,
        num_indices = numindices,
        handle = bgfx.create_index_buffer(bgfx.memory_buffer("w", indices))
    }
end

local ibbuffer = create_ib_buffer(3072)

local function alloc(ibbuffer, numlines)
    local numindices<const> = numlines * 2 * 3
    local start = ibbuffer.offset

    if start + numindices > ibbuffer.num_indices then
        error(("not enough index buffer:%d, %d"):format(start+numindices, ibbuffer.num_indices))
    end

    ibbuffer.offset = start + numindices

    return {
        start = start,
        num = numindices,
        handle = ibbuffer.handle,
    }
end

local function create_dynbuffer(numveritces, desc)
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
        num_vertices    = numveritces,
        offset          = 0,
        layout          = layout,
        handle          = bgfx.create_dynamic_vertex_buffer(numveritces, layout.handle, "a"),
        alloc = function (self, num, vertices)
            local stride = layout.stride
            local start = self.offset / stride
            self.offset = self.offset + num * stride

            if self.offset > self.num_vertices * self.layout.stride then
                error(("not enough dynamic buffer:%d, %d"):format(self.offset, self.num_vertices * self.layout.stride))
            end
    
            local vb = {
                start = start,
                num = num,
                handles = {
                    self.handle,
                }
            }
            if vertices then
                self:update(vb, vertices)
            end
    
            return vb
        end,
        update = function(self, vb, vertices)
            local formatdesc = layout.formatdesc
            assert((#vertices/#formatdesc) == vb.num and self.handle == vb.handles[1])
            bgfx.update(self.handle, vb.start, bgfx.memory_buffer(formatdesc, vertices))
        end,
        free = function(self, vb)
            --TODO
            assert(self.handle == vb.handles[1])
        end,
    }
end

local dyn_vbbuffer = create_dynbuffer(2048, "p3|t20|t31|t32|t33")

local polylines = {}

local defcolor<const> = {0.8, 0.8, 0.8, 1.0}
function ipl.add_lines(points, line_width, color, material)
    color = color or defcolor
    line_width = line_width or 1

    local vertex_elem_num<const> = 14
    local elem_offset = 0
    local vertices = {}
    local function fill_pos(p)        vertices[elem_offset+1],  vertices[elem_offset+2], vertices[elem_offset+3]   = p[1], p[2], p[3] end
    local function fill_uv(u, v)      vertices[elem_offset+4],  vertices[elem_offset+5]                            = u, v             end
    local function fill_prevpos(p)    vertices[elem_offset+6],  vertices[elem_offset+7], vertices[elem_offset+8]   = p[1], p[2], p[3] end
    local function fill_nextpos(p)    vertices[elem_offset+9],  vertices[elem_offset+10],vertices[elem_offset+11]  = p[1], p[2], p[3] end
    local function fille_config(side, width, counter)
                                      vertices[elem_offset+12], vertices[elem_offset+13], vertices[elem_offset+14] = side, width, counter end
    local function next_vertex()      elem_offset = elem_offset + vertex_elem_num end

    local numpoint = #points

    local tex_u_step<const> = 1 / (numpoint-1)
    local tex_u = 0
    for idx=1, numpoint do
        local p = points[idx]
        local prev_p = idx == 1         and p                or points[idx-1]
        local next_p = idx == numpoint  and points[numpoint] or points[idx+1]

        -- positive side
        fill_pos(p)
        fill_uv(tex_u, 0)
        fill_prevpos(prev_p)
        fill_nextpos(next_p)
        local counter = (idx-1) / numpoint
        fille_config(1, 1, counter)

        next_vertex()
        ---

        -- opposite side
        fill_pos(p)
        fill_uv(tex_u, 1)
        fill_prevpos(prev_p)
        fill_nextpos(next_p)
        fille_config(-1, 1, counter)

        next_vertex()
        ---

        tex_u = tex_u + tex_u_step
    end

    local numlines = numpoint-1

    local numvertex = numpoint * 2
    local eid = world:create_entity {
        policy = {
            "ant.render|simplerender",
            "ant.render|polyline",
            "ant.general|name",
        },
        data = {
            polyline = true,
            simplemesh = {
                ib = alloc(ibbuffer, numlines),
                vb = dyn_vbbuffer:alloc(numvertex, vertices),
            },
            material = material or "/pkg/ant.resources/materials/polyline.material",
            state = 1,
            name = "polyline",
        }
    }

    local  lineinfo<const> = {10, 0.0, 0.0, 0.0}
    imaterial.set_property(eid, "u_color",      color)
    imaterial.set_property(eid, "u_line_info",  lineinfo)

    polylines[eid] = {
        mailbox = world:sub{"entity_removed", eid},
        vertices = vertices,
    }
end

local pl_sys = ecs.system "polyline_system"
function pl_sys:data_changed()
    for eid, data in pairs(polylines) do
        for _ in data.mailbox:unpack() do
            local e = world[eid]
            if e.polyline then
                dyn_vbbuffer:free(e._rendercache.vb)
            end
        end
    end
end