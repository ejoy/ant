local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util
local math3d    = require "math3d"

local itimer    = ecs.import.interface "ant.timer|itimer"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local ilight    = ecs.import.interface "ant.render|ilight"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"

--TODO: read from image(png/bmp, etc)
local DAY_NIGHT_COLORS<const> = {
    -- day time
    math3d.ref(math3d.vector(0, 0, 10, 1)),
    math3d.ref(math3d.vector(10, 0, 0, 1)),
    -- mc.BLACK,
    -- math3d.ref(math3d.mul(5.0, mc.YELLOW)),
    -- math3d.ref(math3d.mul(5.0, mc.BLUE)),
    -- math3d.ref(math3d.mul(5.0, mc.RED)),

    -- --night time
    -- math3d.ref(math3d.mul(0.25, mc.BLUE)),
    -- math3d.ref(math3d.mul(0.45, mc.BLUE)),
    -- math3d.ref(math3d.mul(0.15, mc.BLUE)),
    -- math3d.ref(math3d.mul(0.15, mc.BLUE)),
}

local DIRECTIONAL_LIGHT_COLORS<const> = {
    math3d.ref(math3d.vector(1.0, 1.0, 1.0, 0.3)),
    math3d.ref(math3d.vector(0.7, 0.7, 0.7, 1.0)),
}

local dn_sys = ecs.system "daynight_system"

local DEFAULT_DIRECTIONAL_LIGHT_INTENSITY
function dn_sys:init()
    DEFAULT_DIRECTIONAL_LIGHT_INTENSITY = ilight.default_intensity "directional"
end

local function update_cycle(dn, deltaMS)
    local time_rangeMS = dn.time_rangeMS
    local a = dn.current_timeMS % time_rangeMS
    dn.cycle = a / time_rangeMS

    dn.current_timeMS = dn.current_timeMS + deltaMS
    return dn.cycle
end

local function interpolate_in_array(t, arrays, lerp_op)
    local v = (#arrays-1) * t
    local x, y = math.modf(v)

    return lerp_op(arrays[x+1], arrays[x+2], y)
end

local function interpolate_indirect_light_color(t)
    return interpolate_in_array(t, DAY_NIGHT_COLORS, math3d.lerp)
end

local function interpolate_directional_light_color(t)
    return interpolate_in_array(t, DIRECTIONAL_LIGHT_COLORS, mu.lerp)
end

function dn_sys:entity_init()
    for dne in w:select "INIT daynight:in" do
        local dn = dne.daynight
        dn.current_timeMS = dn.time_rangeMS * dn.cycle

        local dnl = dn.light
        dnl.normal = math3d.mark(math3d.vector(dnl.normal))
        dnl.start_dir = math3d.mark(math3d.vector(dnl.start_dir))

        dnl.intensity = 0
    end

    local dne = w:first "daynight:in"
    if dne then
        for dl in w:select "INIT directional_light light:in" do
            dne.daynight.light.intensity = ilight.intensity(dl)
        end
    end
end

function dn_sys:entity_remove()
    for dne in w:select "REMOVED daynight:in" do
        local dnl = dne.daynight.light
        math3d.unmark(dnl.normal)
        math3d.unmark(dnl.start_dir)
    end
end

function dn_sys:data_changed()
    local dne = w:first "daynight:in"
    if dne == nil then
        return 
    end
    local dn = dne.daynight
    local tc = update_cycle(dn, itimer.delta())

    --interpolate indirect light color
    local modulate_color = interpolate_indirect_light_color(tc)
    local sa = imaterial.system_attribs()
    sa:update("u_indirect_modulate_color", modulate_color)

    --move directional light in cycle
    local dl = w:first "directional_light light:in scene:in"
    if dl then
        local dnl = dn.light

        local c<const> = interpolate_directional_light_color()
        ilight.set_color(dl, c)

        local intensity<const> = math3d.index(c, 4)
        ilight.set_intensity(dl, intensity * DEFAULT_DIRECTIONAL_LIGHT_INTENSITY)

        assert(0.0 <= tc and tc <= 1.0, "Invalid time cycle")
        local ntc = tc
        if ntc > 0.5 then
            -- it's a moon time
            ntc = ntc - 0.5
        end

        ntc = ntc * 2

        local q = math3d.quaternion{axis=dnl.normal, r=math.pi*ntc}
        iom.set_direction(dl, math3d.transform(q, dnl.start_dir, 0))
        w:submit(dl)

        --print("cycle:", tc, "intensity:", l, "direction:", math3d.tostring(math3d.transform(q, dnl.start_dir, 0)), "modulate color:", math3d.tostring(modulate_color))
    end
end


local idn = ecs.interface "idaynight"
function idn.set_time_range(rangeMS)
    local dne = w:first "daynight:in"
    local dn = dne.daynight
    dn.time_rangeMS = rangeMS
end

function idn.set_rotation_data(start_dir, normal)
    local dne = w:first "daynight:in"
    local dnl = dne.daynight.light

    math3d.unmark(dnl.normal)
    dnl.normal = math3d.mark(math3d.vector(normal))

    math3d.unmark(dnl.start_dir)
    dnl.start_dir = math3d.mark(math3d.vector(start_dir))
end