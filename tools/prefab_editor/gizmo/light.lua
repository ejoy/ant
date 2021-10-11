local ecs = ...
local world = ecs.world
local w = world.w

local imaterial = ecs.import.interface "ant.asset|imaterial"
local computil  = ecs.import.interface "ant.render|entity"
local ilight    = ecs.import.interface "ant.render|light"
local iom       = ecs.import.interface "ant.objcontroller|obj_motion"
local iss       = ecs.import.interface "ant.scene|iscenespace"
local ies       = ecs.import.interface "ant.scene|ientity_state"
local geo_utils = ecs.require "editor.geometry_utils"

local math3d = require "math3d"
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
function m.highlight(hl)
    local color = hl and HIGHLIGHT_COLOR or NORMAL_COLOR
    for i, v in ipairs(m.eid) do
        imaterial.set_property(v, "u_color", color)
    end
end

function m.bind(eid)
    m.show(false)
    m.current_light = eid
    m.current_gizmo = nil
    if not eid then return end 
    if not m.directional.root then
        m.init()
    end
    local lt = world[eid].light_type
    m.current_gizmo = m[lt]
    if m.current_gizmo then
        m.update_gizmo()
        iom.set_position(m.current_gizmo.root, iom.get_position(eid))
        iom.set_rotation(m.current_gizmo.root, iom.get_rotation(eid))
        world[m.current_gizmo.root].name = world[eid].name
        m.show(true)
    end
end

function m.update()
    iom.set_position(m.current_gizmo.root, iom.get_position(m.current_light))
    iom.set_rotation(m.current_gizmo.root, iom.get_rotation(m.current_light))
    world:pub{"component_changed", "light", m.current_light, "transform"}
end

function m.show(b)
    if m.current_gizmo then
        for i, eid in ipairs(m.current_gizmo.eid) do
            ies.set_state(eid, "visible", b)
        end
    end
end

function m.highlight(b)
    if not m.current_gizmo then return end

    if b then
        for _, eid in ipairs(m.current_gizmo.eid) do
            imaterial.set_property(eid, "u_color", gizmo_const.HIGHTLIGHT_COLOR)
        end
    else
        for _, eid in ipairs(m.current_gizmo.eid) do
            imaterial.set_property(eid, "u_color", gizmo_const.COLOR_GRAY)
        end
    end
end

local function create_gizmo_root(initpos, introt)
    return ecs.create_entity{
		policy = {
			"ant.general|name",
            "ant.scene|scene_object",
		},
		data = {
            reference = true,
			name = "gizmo root",
            scene = {srt = {t = initpos or {0,0,0}, r = introt or {0,0,0,1}}},
		},
    }
end

local function create_directional_gizmo(initpos, introt)
    local root = create_gizmo_root(initpos, introt)
    local circle_eid = computil.create_circle_entity(RADIUS, SLICES, {}, "directional gizmo circle")
    ies.set_state(circle_eid, "auxgeom", true)
    imaterial.set_property(circle_eid, "u_color", gizmo_const.COLOR_GRAY)
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
        imaterial.set_property(line_eid, "u_color", gizmo_const.COLOR_GRAY)
        iss.set_parent(line_eid, root)
        alleid[#alleid + 1] = line_eid
        ies.set_state(line_eid, "visible", false)
    end
    m.directional.root = root
    m.directional.eid = alleid
end

local function init_entity(eid, root)
    imaterial.set_property(eid, "u_color", gizmo_const.COLOR_GRAY)
    ies.set_state(eid, "auxgeom", true)
    iss.set_parent(eid, root)
end

local function update_circle_vb(eid, radian)
    local rc = world[eid]._rendercache
    local vbdesc, ibdesc = rc.vb, rc.ib
    local vb, _ = geo_utils.get_circle_vb_ib(radian, gizmo_const.ROTATE_SLICES)
    bgfx.update(vbdesc.handles[1], 0, bgfx.memory_buffer("fffd", vb));
end

local function update_point_gizmo()
    local root = m.point.root
    local radius = ilight.range(m.current_light)
    
    if #m.point.eid == 0 then
        local c0 = geo_utils.create_dynamic_circle(radius, gizmo_const.ROTATE_SLICES, {}, "light gizmo circle")
        init_entity(c0, root)
        local c1 = geo_utils.create_dynamic_circle(radius, gizmo_const.ROTATE_SLICES, {r = math3d.tovalue(math3d.quaternion{0, math.rad(90), 0})}, "light gizmo circle")
        init_entity(c1, root)
        local c2 = geo_utils.create_dynamic_circle(radius, gizmo_const.ROTATE_SLICES, {r = math3d.tovalue(math3d.quaternion{math.rad(90), 0, 0})}, "light gizmo circle")
        init_entity(c2, root)
        m.point.eid = {c0, c1, c2}
    else
        update_circle_vb(m.point.eid[1], radius)
        update_circle_vb(m.point.eid[2], radius)
        update_circle_vb(m.point.eid[3], radius)
    end
end

local function update_spot_gizmo()
    local range = ilight.range(m.current_light)
    local radian = ilight.outter_radian(m.current_light) or 10
    local radius = range * math.tan(radian * 0.5)
    if #m.spot.eid == 0 then
        local root = m.spot.root
        local c0 = geo_utils.create_dynamic_circle(radius, gizmo_const.ROTATE_SLICES, {t = {0, 0, range}}, "light gizmo circle")
        init_entity(c0, root)
        local line0 = geo_utils.create_dynamic_line(nil, {0, 0, 0}, {0, radius, range}, "line")
        init_entity(line0, root)
        local line1 = geo_utils.create_dynamic_line(nil, {0, 0, 0}, {radius, 0, range}, "line")
        init_entity(line1, root)
        local line2 = geo_utils.create_dynamic_line(nil, {0, 0, 0}, {0, -radius, range}, "line")
        init_entity(line2, root)
        local line3 = geo_utils.create_dynamic_line(nil, {0, 0, 0}, {-radius, 0, range}, "line")
        init_entity(line3, root)
        local line4 = geo_utils.create_dynamic_line(nil, {0, 0, 0}, {0, 0, range}, "line")
        init_entity(line4, root)
        m.spot.eid = {line0, line1, line2, line3, line4, c0}
    else
        update_circle_vb(m.spot.eid[6], radius)
        iom.set_position(m.spot.eid[6], {0, 0, range})

        local function update_vb(eid, tp2)
            local vb = {
                0, 0, 0, 0xffffffff,
                tp2[1], tp2[2], tp2[3], 0xffffffff,
            }
            local rc = world[eid]._rendercache
            local vbdesc = rc.vb
            bgfx.update(vbdesc.handles[1], 0, bgfx.memory_buffer("fffd", vb));
        end
        update_vb(m.spot.eid[1], {0, radius, range})
        update_vb(m.spot.eid[2], {radius, 0, range})
        update_vb(m.spot.eid[3], {0, -radius, range})
        update_vb(m.spot.eid[4], {-radius, 0, range})
        update_vb(m.spot.eid[5], {0, 0, range})
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
    for k,v in pairs(m.billboard) do
        world:remove_entity(v)
    end
    m.billboard = {}
    m.current_light = nil
    m.show(false)
end

function m.on_remove_light(eid)
    --if not m.billboard[eid] then return end
    --world:remove_entity(m.billboard[eid])
    m.billboard[eid] = nil
    m.current_light = nil
    m.show(false)
end

function m.init()
    create_directional_gizmo(iom.get_position(m.current_light), iom.get_rotation(m.current_light))
    m.point.root = create_gizmo_root()
    update_point_gizmo()
    m.spot.root = create_gizmo_root()
    update_spot_gizmo()

    for i, eid in ipairs(m.directional.eid) do
        ies.set_state(eid, "visible", false)
    end
    for i, eid in ipairs(m.point.eid) do
        ies.set_state(eid, "visible", false)
    end
    for i, eid in ipairs(m.spot.eid) do
        ies.set_state(eid, "visible", false)
    end
end

return m