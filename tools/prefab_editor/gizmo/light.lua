local math3d = require "math3d"
local ilight
local iss
local computil
local iom
local ies
local imaterial
local m = {
    directional = {
        eid = {}
    },
    point = {
        eid = {}
    },
    spot = {
        eid = {}
    }
}
local NORMAL_COLOR = {1, 1, 1, 1}
local HIGHLIGHT_COLOR = {0.5, 0.5, 0, 1}
local RADIUS = 0.25
local SLICES = 10
local LENGTH = 1
local DEFAULT_POSITION = {0, 0, 0}
local DEFAULT_ROTATE = {2.4, 0, 0}
function m.highlight(hl)
    local color = hl and HIGHLIGHT_COLOR or NORMAL_COLOR
    for i, v in ipairs(m.eid) do
        imaterial.set_property(v, "u_color", color)
    end
end

function m.bind(eid)
    if not eid or not world[eid].light_type then return end
    m.current_light = eid
    if not m.directional.root then
        m.init()
    end
    if world[eid].light_type == "directional" then
        m.current_gizmo = m.directional
        ilight.active_directional_light(eid)
    elseif world[eid].light_type == "point" then
        m.current_gizmo = m.point
    elseif world[eid].light_type == "spot"then
        m.current_gizmo = m.spot
    end
    iom.set_position(m.current_gizmo.root, iom.get_position(eid))
    iom.set_rotation(m.current_gizmo.root, iom.get_rotation(eid))
    world[m.current_gizmo.root].name = world[eid].name
end

function m.update()
    iom.set_position(m.current_gizmo.root, iom.get_position(m.current_light))
    iom.set_rotation(m.current_gizmo.root, iom.get_rotation(m.current_light))
end

function m.reset()
    -- if not m.root then return end
    -- m.bind(m.default_light)
    -- local default_quat = math3d.quaternion(DEFAULT_ROTATE)
    -- local default_pos = math3d.vector(DEFAULT_POSITION)
    -- iom.set_position(m.root, default_pos)
    -- iom.set_rotation(m.root, default_quat)
    -- iom.set_position(m.current_light, default_pos)
    -- iom.set_rotation(m.current_light, default_quat)
    m.show(false)
end

function m.show(b)
    if m.current_gizmo then
        for i, eid in ipairs(m.current_gizmo.eid) do
            ies.set_state(eid, "visible", b)
        end
    end
end

local function create_directional_gizmo()
    local root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = {},
			name = "directional gizmo root",
		},
    }
    local circle_eid = computil.create_circle_entity(RADIUS, SLICES, {}, "directional gizmo circle")
    ies.set_state(circle_eid, "auxgeom", true)
    imaterial.set_property(circle_eid, "u_color", NORMAL_COLOR)
    iss.set_parent(circle_eid, root)
    ies.set_state(circle_eid, "visible", false)
    local alleid = {}
    alleid[#alleid + 1] = circle_eid
    local radian_step = 2 * math.pi / SLICES
    for s=0, SLICES-1 do
        local radian = radian_step * s
        local x, y = math.cos(radian) * RADIUS, math.sin(radian) * RADIUS
        local line_eid = computil.create_line_entity({}, {x, y, 0}, {x, y, LENGTH})
        ies.set_state(line_eid, "auxgeom", true)
        imaterial.set_property(line_eid, "u_color", NORMAL_COLOR)
        iss.set_parent(line_eid, root)
        alleid[#alleid + 1] = line_eid
        ies.set_state(line_eid, "visible", false)
    end
    m.directional.root = root
    m.directional.eid = alleid
end

local gizmo_const = require "gizmo.const"
local function init_entity(eid, root)
    imaterial.set_property(eid, "u_color", gizmo_const.COLOR_GRAY)
    ies.set_state(eid, "auxgeom", true)
    iss.set_parent(eid, root)
    ies.set_state(eid, "visible", false)
end

local function create_point_gizmo()
    local root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = {},
			name = "point gizmo root",
		},
    }
    local radius = ilight.range(m.current_light)
    local c0 = computil.create_circle_entity(radius, gizmo_const.ROTATE_SLICES, {}, "light gizmo circle")
    init_entity(c0, root)
    local c1 = computil.create_circle_entity(radius, gizmo_const.ROTATE_SLICES, {r = math3d.tovalue(math3d.quaternion{0, math.rad(90), 0})}, "light gizmo circle")
    init_entity(c1, root)
    local c2 = computil.create_circle_entity(radius, gizmo_const.ROTATE_SLICES, {r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})}, "light gizmo circle")
    init_entity(c2, root)
    m.point.root = root
    m.point.eid = {c0, c1, c2}
end

local function create_spot_gizmo()
    local root = world:create_entity{
		policy = {
			"ant.general|name",
			"ant.scene|transform_policy",
		},
		data = {
			transform = {},
			name = "point gizmo root",
		},
    }
    local radian = ilight.radian(m.current_light)
    local range = ilight.range(m.current_light)
    local c0 = computil.create_circle_entity(radian, gizmo_const.ROTATE_SLICES, {t = {0, 0, range}}, "light gizmo circle")
    init_entity(c0, root)
    local line0 = computil.create_line_entity({}, {0, 0, 0}, {0, radian, range})
    init_entity(line0, root)
    local line1 = computil.create_line_entity({}, {0, 0, 0}, {radian, 0, range})
    init_entity(line1, root)
    local line2 = computil.create_line_entity({}, {0, 0, 0}, {0, -radian, range})
    init_entity(line2, root)
    local line3 = computil.create_line_entity({}, {0, 0, 0}, {-radian, 0, range})
    init_entity(line3, root)
    m.spot.root = root
    m.spot.eid = {line0, line1, line2, line3, c0}
end

function m.init()
    create_directional_gizmo()
    create_point_gizmo()
    create_spot_gizmo()
    m.show(false)
end

return function(w)
    world = w
    imaterial = world:interface "ant.asset|imaterial"
    computil = world:interface "ant.render|entity"
    ilight = world:interface "ant.render|light"
    iom = world:interface "ant.objcontroller|obj_motion"
    iss = world:interface "ant.scene|iscenespace"
    ies = world:interface "ant.scene|ientity_state"
    return m
end