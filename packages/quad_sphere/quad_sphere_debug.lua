local ecs = ...
local world = ecs.world

local math3d    = require "math3d"
local ctrunkid  = require "trunkid_class"
local constant  = require "constant"

local ientity   = world:interface "ant.render|entity"
local iqs       = world:interface "ant.quad_sphere|iquad_sphere"
local iqsd      = ecs.interface "iquad_sphere_debug"



function iqsd.add_trunk_line_grid(eid)
    local e = world[eid]
    local qs = e._quad_sphere
    local trunkid = qs.trunkid
    local vertices = ctrunkid.tile_vertices(trunkid, qs)

    local mesh = ientity.create_mesh({"p3", vertices}, constant.trunk_line_indices)
    return ientity.create_simple_render_entity(
        "quad_sphere_line",
        "/pkg/ant.resources/materials/line.material",
        mesh)
end

function iqsd.add_inscribed_cube(eid, color)
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

function iqsd.add_solid_angle(eid, color)
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

function iqsd.add_axis(targetpos)
    local srt = iqs.tangent_matrix(targetpos)
    local xaxis = math3d.tovalue(math3d.add(targetpos, math3d.normalize(math3d.index(srt, 1))))
    local yaxis = math3d.tovalue(math3d.add(targetpos, math3d.normalize(math3d.index(srt, 2))))
    local zaxis = math3d.tovalue(math3d.add(targetpos, math3d.normalize(math3d.index(srt, 3))))

    local axisorigin = targetpos --math3d.muladd(math3d.normalize(targetpos), 0.1, targetpos)
    local ao = math3d.tovalue(axisorigin)
    local vertices = {
        ao[1], ao[2], ao[3],            0xff0000ff,
        xaxis[1], xaxis[2], xaxis[3],   0xff0000ff,
        ao[1], ao[2], ao[3],            0xff00ff00,
        yaxis[1], yaxis[2], yaxis[3],   0xff00ff00,
        ao[1], ao[2], ao[3],            0xffff0000,
        zaxis[1], zaxis[2], zaxis[3],   0xffff0000,
    }

    --ies.set_state(qs_eids[1], "visible",)

    local axismesh = ientity.create_mesh{"p3|c40niu", vertices}
    ientity.create_simple_render_entity(
        "axis",
        "/pkg/ant.resources/materials/line.material",
        axismesh
    )
end