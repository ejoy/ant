local ecs = ...
local world = ecs.world
local w = world.w

local bgfx      = require "bgfx"
local math3d    = require "math3d"
local imaterial = ecs.require "ant.render|material"
local irender   = ecs.require "ant.render|render"
local renderpkg = import_package "ant.render"
local layoutmgr = renderpkg.layoutmgr

local ipl       = {}

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

-- todo: Need better solution to release this handle
-- try to use asset manager ?
local release_handle = {
	__gc = function(self)
		local h = self.handle
		if h then
			self.handle = nil
			bgfx.destroy(h)
		end
	end
}

local function create_strip_index_buffer(max_lines)
    local function create_ib_buffer(max_lines)
        local stride = 6 * 2
        local indices = bgfx.memory_buffer(max_lines * stride)
        local offset = 0
        
        for i=1, max_lines do
            indices[stride*(i-1)+1] = ("HHHHHH"):pack(
                    offset + 0,
                    offset + 2,
                    offset + 3,
                    offset + 3,
                    offset + 1,
                    offset + 0)
            offset = offset + 2
        end
    
        return bgfx.create_index_buffer(indices)
    end

    return setmetatable( {
        offset = 0,
        num_indices = max_lines,
        handle = create_ib_buffer(max_lines),
    }, release_handle)
end

local strip_ib = create_strip_index_buffer(3072)
local function create_vb_desc(fmt)
    local ffmt<const>  = layoutmgr.correct_layout(fmt)
    return {
        layout = layoutmgr.get(ffmt),
        desc_str = layoutmgr.vertex_desc_str(ffmt),
    }
end
local stripline_desc = create_vb_desc "p3|t20|t31|t32|t33"
local linelist_desc = create_vb_desc "p3|t20|t31|t32"

local function generate_stripline_vertices(points, uv_rotation, loop)
    local numpoint = #points
    local numv = numpoint * 2
    local stride = stripline_desc.layout.stride
    local elem_offset = 1
    local fmt<const> = ('f'):rep(14)
    local vertices = bgfx.memory_buffer(numv * stride)
    local function fill_vertex(p, prev_p, next_p, u, v, side, width, counter)
        vertices[elem_offset] = fmt:pack(
            p[1], p[2], p[3],
            u, v,
            side, width, counter,
            prev_p[1], prev_p[2], prev_p[3],
            next_p[1], next_p[2], next_p[3]
        )
        elem_offset = elem_offset + stride
    end

    local delta<const> = 1/(numpoint-1)

    local function prev_point(idx)
        if idx == 1 then
            return loop and points[numpoint-1] or points[1]
        end
        return points[idx-1]
    end

    local function next_point(idx)
        if idx == numpoint then
            return loop and points[2] or points[numpoint]
        end
        return points[idx+1]
    end
    local counter = 0
    local m
    if uv_rotation then
        local c, s = math.cos(uv_rotation), math.sin(uv_rotation)
        m = {
            {c, s,},
            {-s, c,},
        }
    end

    local function rotate_uv(m, uv)
        local function dot(v0, v1)
            return v0[1]*v1[1] + v0[2]*v1[2]
        end
        local u, v = dot(m[1], uv), dot(m[2], uv)
        uv[1], uv[2] = u, v
    end
    for idx=1, numpoint do
        local p = points[idx]
        local prev_p = prev_point(idx)
        local next_p = next_point(idx)

        local tex_v<const> = counter
        local uv0, uv1 = {0, tex_v}, {1, tex_v}
        if m then
            rotate_uv(m, uv0)
            rotate_uv(m, uv1)
        end
        fill_vertex(p, prev_p, next_p, uv0[1], uv0[2],  1, 1, counter)
        fill_vertex(p, prev_p, next_p, uv1[1], uv1[2], -1, 1, counter)

        counter = counter + delta
    end

    return vertices
end

local function add_polylines(polymesh, line_width, color, material, srt, render_layer, hide)
    return world:create_entity {
        policy = {
            "ant.render|simplerender",
            "ant.polyline|polyline",
        },
        data = {
            polyline = {
                width = line_width,
                color = math3d.ref(math3d.vector(color)),
            },
            scene = {s = srt.s, r = srt.r, t = srt.t, parent = srt.parent},
            mesh_result = polymesh,
            material    = material,
            visible     = not hide,
            render_layer= render_layer or "background",
            on_ready = function (e)
                w:extend(e, "polyline:in")
                local pl = e.polyline
                imaterial.set_property(e, "u_line_info", math3d.vector(pl.width, 0.0, 0.0, 0.0))
                imaterial.set_property(e, "u_color", pl.color)
            end
        },
    }
end

local defcolor<const> = {1.0, 1.0, 1.0, 1.0}

function ipl.create_linestrip_mesh(points, line_width, color, uv_rotation, loop)
    if #points < 2 then
        error(("strip line need at least 2 point:%d"):format(#points))
    end
    color = color or defcolor
    line_width = line_width or 1

    if loop then
        points[#points+1] = points[1]
    end

    local vertices = generate_stripline_vertices(points, uv_rotation, loop)
    local numlines = #points-1
    local numv = #points*2

    return {
        ib = {
            start = 0,
            num = numlines * 2 * 3,
            handle = strip_ib.handle,
			memory = true,	-- prevent to delete this handle
        },
        vb = {
            start = 0,
            num = numv,
            handle = bgfx.create_vertex_buffer(vertices, stripline_desc.layout.handle),
        },
    }
end


function ipl.add_strip_lines(points, line_width, color, material, loop, srt, render_layer, hide)
    local polymesh = ipl.create_linestrip_mesh(points, line_width, color, loop)
    return add_polylines(polymesh, line_width, color, material or "/pkg/ant.resources/materials/polyline.material", srt or {}, render_layer, hide)
end

local function generate_linelist_vertices(points)
    local numpoint = #points
    local numv = (numpoint / 2) * 4
    local elem_offset = 1
    local stride = linelist_desc.layout.stride
    local vertices = bgfx.memory_buffer(stride*numv)
    local fmt<const> = ('f'):rep(11)
    local function fill_vertex(p, d, u, v, side, width, counter)
        --TODO:we should compress this vertex data, for example: float16 for pos/normal, int16 for uv, int8 for side/width, counter
        vertices[elem_offset] = fmt:pack(
            p[1], p[2], p[3],
            u, v,
            side, width, counter,
            d[1], d[2], d[3]
        )
        elem_offset = elem_offset + stride
    end

    

    local function sub(p0, p1)
        return {p1[1]-p0[1], p1[2]-p0[2], p1[3]-p0[3]}
    end

    for idx=1, numpoint, 2 do
        local p0, p1 = points[idx], points[idx+1]
        local d0, d1 = sub(p1, p0), sub(p0, p1)
        local c0, c1 = (idx-1) / numpoint, idx / numpoint

        fill_vertex(p0, d0, 0, 0,  1, 1, c0)
        fill_vertex(p0, d0, 0, 1, -1, 1, c0)

        fill_vertex(p1, d0, 1, 0,  1, 1, c1)
        fill_vertex(p1, d0, 1, 1, -1, 1, c1)
    end

    return vertices
end

function ipl.create_linelist_mesh(pointlist, line_width, color)
    local numpoint = #pointlist
    if numpoint == 0 or numpoint % 2 ~= 0 then
        error(("privoided point for line's number must multiple of 2: %d"):format(numpoint))
    end

    color = color or defcolor
    line_width = line_width or 1

    local vertices = generate_linelist_vertices(pointlist)
    local numlines = numpoint // 2
    local numv = numlines * 4
    return {
        ib = {
            start = 0,
            num = numlines * 2 * 3,
            handle = irender.quad_ib(),
			memory = true,	-- prevent to delete ib.handle
        },
        vb = {
            start = 0,
            num = numv,
            handle = bgfx.create_vertex_buffer(vertices, linelist_desc.layout.handle),
        }
    }
end

function ipl.add_linelist(pointlist, line_width, color, material, srt, render_layer)
    local polymesh = ipl.create_linelist_mesh(pointlist, line_width, color)
    return add_polylines(polymesh, line_width, color, material or "/pkg/ant.resources/materials/polylinelist.material", srt or {}, render_layer)
end

return ipl
