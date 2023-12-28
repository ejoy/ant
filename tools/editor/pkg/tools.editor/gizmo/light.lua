local ecs = ...
local world = ecs.world
local w = world.w

local imaterial = ecs.require "ant.asset|material"
local computil  = ecs.require "ant.render|components.entity"
local ilight    = ecs.require "ant.render|light.light"
local iom       = ecs.require "ant.objcontroller|obj_motion"
local ivs       = ecs.require "ant.render|visible_state"
local geo_utils = ecs.require "editor.geometry_utils"
local math3d    = require "math3d"
local gizmo_const = require "gizmo.const"
local bgfx = require "bgfx"

local m = {
    directional = {
        eid = {}
    },
    point = {
        eid = {}
    },
    spot = {
        eid = {}
    },
    billboard = {}
}
local NORMAL_COLOR = {1, 1, 1, 1}
local HIGHLIGHT_COLOR = {0.5, 0.5, 0, 1}
local RADIUS = 0.25
local SLICES = 10
local LENGTH = 1
local DEFAULT_POSITION = {0, 0, 0}
local DEFAULT_ROTATE = {2.4, 0, 0}

function m.on_target(eid)
    m.show(false)
    m.current_light = nil
    m.current_gizmo = nil
    if not eid then
        return
    end
    local ec <close> = world:entity(eid, "light?in")
    if not ec.light then
        return
    end
    m.current_light = eid
    local lt = ec.light.type
    m.current_gizmo = m[lt]
    if m.current_gizmo then
        m.update_gizmo()
        local er <close> = world:entity(m.current_gizmo.root)
        iom.set_position(er, iom.get_position(ec))
        iom.set_rotation(er, iom.get_rotation(ec))
        -- er.name = ec.name
        m.show(true)
    end
end

function m.update()
    local er <close> = world:entity(m.current_gizmo.root)
    local ec <close> = world:entity(m.current_light)
    iom.set_position(er, iom.get_position(ec))
    iom.set_rotation(er, iom.get_rotation(ec))
    world:pub{"component_changed", "light", m.current_light, "transform"}
end

function m.show(b)
    if m.current_gizmo then
        for i, eid in ipairs(m.current_gizmo.eid) do
            local e <close> = world:entity(eid)
            ivs.set_state(e, "main_view", b)
        end
    end
end

function m.highlight(b)
    if not m.current_gizmo then return end

    if b then
        for _, eid in ipairs(m.current_gizmo.highlight_eid) do
            local e <close> = world:entity(eid)
            imaterial.set_property(e, "u_color", gizmo_const.COLOR.HIGHLIGHT)
        end
    else
        for _, eid in ipairs(m.current_gizmo.highlight_eid) do
            local e <close> = world:entity(eid)
            imaterial.set_property(e, "u_color", math3d.vector(gizmo_const.COLOR.GRAY))
        end
    end
end

local function create_gizmo_root(initpos, initrot)
    return world:create_entity{
		policy = {
            "ant.scene|scene_object",
		},
		data = {
            -- scene = {t = initpos or {0, 5, 0}, r = initrot or {math.rad(130), 0, 0, 1}},
            scene = {t = initpos, r = initrot},
		},
        tag = {
            "gizmo root"
        }
    }
end
local ipl = ecs.require "ant.polyline|polyline"
local geopkg = import_package "ant.geometry"
local geolib = geopkg.geometry
local LINEWIDTH = 3
local function get_points(vertices)
    local points = {}
    for i = 1, #vertices, 3 do
        points[#points + 1] = {vertices[i], vertices[i+1], vertices[i+2]}
    end
    points[#points + 1] = {vertices[1], vertices[2], vertices[3]}
    return points
end
local function create_directional_gizmo(initpos, initrot)
    local root = create_gizmo_root(initpos, initrot)
    local vertices, _ = geolib.circle(RADIUS, SLICES)
    local circle_eid = ipl.add_strip_lines(get_points(vertices), LINEWIDTH, gizmo_const.COLOR.GRAY, "/pkg/tools.editor/resource/materials/polyline.material", false, {parent = root}, "translucent", true)
    local alleid = {}
    alleid[#alleid + 1] = circle_eid
    local radian_step = 2 * math.pi / SLICES
    for s=0, SLICES-1 do
        local radian = radian_step * s
        local x, y = math.cos(radian) * RADIUS, math.sin(radian) * RADIUS
        local line_eid = ipl.add_strip_lines({{x, y, 0}, {x, y, LENGTH}}, LINEWIDTH, gizmo_const.COLOR.GRAY, "/pkg/tools.editor/resource/materials/polyline.material", false, {parent = root}, "translucent", true)
        alleid[#alleid + 1] = line_eid
    end
    m.directional.root = root
    m.directional.eid = alleid
    m.directional.highlight_eid = alleid
end

local function update_point_gizmo()
    local root = m.point.root
    local range = 1.0
    if m.current_light then
        local e <close> = world:entity(m.current_light, "light:in")
        range = ilight.range(e)
    end
    local radius = range
    if #m.point.eid == 0 then
        local vertices, _ = geolib.circle(1, gizmo_const.ROTATE_SLICES)
        local points = get_points(vertices)
        local c0 = ipl.add_strip_lines(points, LINEWIDTH, gizmo_const.COLOR.GRAY, "/pkg/tools.editor/resource/materials/polyline.material", false, {parent = root, s = radius}, "translucent", true)
        local c1 = ipl.add_strip_lines(points, LINEWIDTH, gizmo_const.COLOR.GRAY, "/pkg/tools.editor/resource/materials/polyline.material", false, {parent = root, s = radius, r = math3d.tovalue(math3d.quaternion{0, math.rad(90), 0})}, "translucent", true)
        local c2 = ipl.add_strip_lines(points, LINEWIDTH, gizmo_const.COLOR.GRAY, "/pkg/tools.editor/resource/materials/polyline.material", false, {parent = root, s = radius, r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})}, "translucent", true)
        m.point.eid = {c0, c1, c2}
        m.point.highlight_eid = m.point.eid
    else
        local e0 <close> = world:entity(m.point.eid[1])
        iom.set_scale(e0, radius)
        local e1 <close> = world:entity(m.point.eid[2])
        iom.set_scale(e1, radius)
        local e2 <close> = world:entity(m.point.eid[3])
        iom.set_scale(e2, radius)
    end
end

local function update_spot_gizmo()
    local range = 1.0
    local radian = math.rad(30)
    if m.current_light then
        local e <close> = world:entity(m.current_light, "light:in")
        range = ilight.range(e)
        radian = ilight.outter_radian(e) or math.rad(30)
    end
    local halfAngle = radian * 0.5
    local radius = range * math.tan(halfAngle)
    local scale = range / math.cos(halfAngle)
    local q1 = math3d.quaternion{halfAngle, 0, 0}
    local q2 = math3d.quaternion{-halfAngle, 0, 0}
    local q3 = math3d.quaternion{0, halfAngle, 0}
    local q4 = math3d.quaternion{0, -halfAngle, 0}
    if #m.spot.eid == 0 then
        local vertices, _ = geolib.circle(1, gizmo_const.ROTATE_SLICES)
        local points = get_points(vertices)
        local linesPoints = {{0, 0, 0}, {0, 0, 1}}
        local root = m.spot.root
        m.spot.eid = {
            ipl.add_strip_lines(linesPoints, LINEWIDTH, gizmo_const.COLOR.GRAY, "/pkg/tools.editor/resource/materials/polyline.material", false, {parent = root, s = scale, r = math3d.tovalue(q1)}, "translucent", true),
            ipl.add_strip_lines(linesPoints, LINEWIDTH, gizmo_const.COLOR.GRAY, "/pkg/tools.editor/resource/materials/polyline.material", false, {parent = root, s = scale, r = math3d.tovalue(q2)}, "translucent", true),
            ipl.add_strip_lines(linesPoints, LINEWIDTH, gizmo_const.COLOR.GRAY, "/pkg/tools.editor/resource/materials/polyline.material", false, {parent = root, s = scale, r = math3d.tovalue(q3)}, "translucent", true),
            ipl.add_strip_lines(linesPoints, LINEWIDTH, gizmo_const.COLOR.GRAY, "/pkg/tools.editor/resource/materials/polyline.material", false, {parent = root, s = scale, r = math3d.tovalue(q4)}, "translucent", true),
            ipl.add_strip_lines(linesPoints, LINEWIDTH, gizmo_const.COLOR.GRAY, "/pkg/tools.editor/resource/materials/polyline.material", false, {parent = root, s = range}, "translucent", true),
            ipl.add_strip_lines(points, LINEWIDTH, gizmo_const.COLOR.GRAY, "/pkg/tools.editor/resource/materials/polyline.material", false, {parent = root, s = radius, t = {0, 0, range}}, "translucent", true)
        }
        m.spot.highlight_eid = {m.spot.eid[5], m.spot.eid[6]}
    else
        local e1 <close> = world:entity(m.spot.eid[1])
        iom.set_scale(e1, scale)
        iom.set_rotation(e1, q1)
        local e2 <close> = world:entity(m.spot.eid[2])
        iom.set_scale(e2, scale)
        iom.set_rotation(e2, q2)
        local e3 <close> = world:entity(m.spot.eid[3])
        iom.set_scale(e3, scale)
        iom.set_rotation(e3, q3)
        local e4 <close> = world:entity(m.spot.eid[4])
        iom.set_scale(e4, scale)
        iom.set_rotation(e4, q4)
        local e5 <close> = world:entity(m.spot.eid[5])
        iom.set_scale(e5, range)
        local e6 <close> = world:entity(m.spot.eid[6])
        iom.set_position(e6, math3d.vector(0, 0, range))
        iom.set_scale(e6, radius)
    end
end

function m.update_gizmo()
    if m.current_gizmo == m.spot then
        update_spot_gizmo()
    elseif m.current_gizmo == m.point then
        update_point_gizmo()
    end
end

function m.clear()
    for _,v in pairs(m.billboard) do
        w:remove(v)
    end
    m.billboard = {}
    m.current_light = nil
    m.show(false)
end

function m.on_remove_light(eid)
    --if not m.billboard[eid] then return end
    --w:remove(m.billboard[eid])
    m.billboard[eid] = nil
    -- m.current_light = nil
    -- m.show(false)
    m.on_target()
end

local inited = false
function m.init()
    if inited then return end
    local initpos
    local initrot
    if m.current_light then
        local e <close> = world:entity(m.current_light)
        initpos = iom.get_position(e)
        initrot = iom.get_rotation(e)
    end
    
    create_directional_gizmo(initpos, initrot)
    m.point.root = create_gizmo_root()
    update_point_gizmo()
    m.spot.root = create_gizmo_root()
    update_spot_gizmo()
    inited = true
end

return m