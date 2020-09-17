local math3d = require "math3d"
local ilight
local iss
local computil
local iom
local ies
local imaterial
local m = {eid = {}}
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
    if world[eid].light_type ~= "directional" then return end
    if not m.root then
        m.init()
    end
    ilight.active_directional_light(eid)
    m.current_light = eid
    iom.set_position(m.root, iom.get_position(eid))
    iom.set_rotation(m.root, iom.get_rotation(eid))
    world[m.root].name = world[eid].name
end

function m.update()
    iom.set_position(m.root, iom.get_position(m.current_light))
    iom.set_rotation(m.root, iom.get_rotation(m.current_light))
end

function m.reset()
    m.bind(m.default_light)
    local default_quat = math3d.quaternion(DEFAULT_ROTATE)
    local default_pos = math3d.vector(DEFAULT_POSITION)
    iom.set_position(m.root, default_pos)
    iom.set_rotation(m.root, default_quat)
    iom.set_position(m.current_light, default_pos)
    iom.set_rotation(m.current_light, default_quat)
    m.show(false)
end

function m.show(b)
    for i, eid in ipairs(m.eid) do
        ies.set_state(eid, "visible", b)
    end
end

function m.init()
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
    m.eid[#m.eid + 1] = circle_eid
    local radian_step = 2 * math.pi / SLICES
    for s=0, SLICES-1 do
        local radian = radian_step * s
        local x, y = math.cos(radian) * RADIUS, math.sin(radian) * RADIUS
        local line_eid = computil.create_line_entity({}, {x, y, 0}, {x, y, LENGTH})
        ies.set_state(line_eid, "auxgeom", true)
        imaterial.set_property(line_eid, "u_color", NORMAL_COLOR)
        iss.set_parent(line_eid, root)
        m.eid[#m.eid + 1] = line_eid
    end
    m.root = root
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