local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util
local math3d    = require "math3d"
local image     = require "image"
local fs        = require "filesystem"

local itimer    = ecs.import.interface "ant.timer|itimer"
local imaterial = ecs.import.interface "ant.asset|imaterial"
local ilight    = ecs.import.interface "ant.render|ilight"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"

--just keep them to debug code
-- local DAY_NIGHT_COLORS<const> = {
--     -- day time
--     math3d.ref(math3d.vector(0, 0, 10, 1)),
--     math3d.ref(math3d.vector(10, 0, 0, 1)),
--     -- mc.BLACK,
--     -- math3d.ref(math3d.mul(5.0, mc.YELLOW)),
--     -- math3d.ref(math3d.mul(5.0, mc.BLUE)),
--     -- math3d.ref(math3d.mul(5.0, mc.RED)),

--     -- --night time
--     -- math3d.ref(math3d.mul(0.25, mc.BLUE)),
--     -- math3d.ref(math3d.mul(0.45, mc.BLUE)),
--     -- math3d.ref(math3d.mul(0.15, mc.BLUE)),
--     -- math3d.ref(math3d.mul(0.15, mc.BLUE)),
-- }

-- local DIRECTIONAL_LIGHT_COLORS<const> = {
--     math3d.ref(math3d.vector(1.0, 1.0, 1.0, 0.3)),
--     math3d.ref(math3d.vector(0.7, 0.7, 0.7, 1.0)),
-- }

local DAYNIGHT = {
    DAY = {
        DIRECT_COLORS = {},
        DIRECT_INTENSITIES = {},
        INDIRECT_COLORS = {},
    },
    NIGHT = {
        DIRECT_COLORS = {},
        DIRECT_INTENSITIES = {},
        INDIRECT_COLORS = {},
    }
}

local dn_sys = ecs.system "daynight_system"

local function read_image_content(p)
    local f<close> = fs.open(fs.path(p), "rb")
    local c = f:read "a"
    return image.parse(c, true)
end

local function read_colors_from_files(srcfiles, cyclevalues)
    local direct_info, direct_c         = read_image_content(srcfiles.direct)
    local indirect_info, indirect_c     = read_image_content(srcfiles.indirect)
    local intensity_info, intensity_c   = read_image_content(srcfiles.intensity)

    assert(direct_info.depth == 1 and (not direct_info.cubemap))
    assert(indirect_info.depth == 1 and (not indirect_info.cubemap))

    local direct_step<const>    = direct_info.bitsPerPixel // 8
    local indirect_step<const>  = indirect_info.bitsPerPixel // 8
    local intensity_step<const> = intensity_info.bitsPerPixel // 8

    local function to_float(v, ...)
        if v then
            return v / 255.0, to_float(...)
        end
    end

    local directcolors, direct_intensities, indirectcolors = 
        cyclevalues.DIRECT_COLORS, cyclevalues.DIRECT_INTENSITIES, cyclevalues.INDIRECT_COLORS

    --we just need a row
    local direct_offset, indirect_offset, intensity_offset = 1, 1, 1
    for iw=1, direct_info.width do
        local r, g, b = to_float(('BBB'):unpack(direct_c, direct_offset))
        directcolors[iw] = math3d.ref(math3d.vector(r, g, b, 0.0))
        direct_offset = direct_offset + direct_step
    end

    for iw=1, intensity_info.width do
        direct_intensities[iw] = to_float(('B'):unpack(intensity_c, intensity_offset))
        intensity_offset = intensity_offset + intensity_step
    end

    for iw=1, indirect_info.width do
        local r, g, b = to_float(('BBB'):unpack(indirect_c, indirect_offset))
        indirectcolors[iw] = math3d.ref(math3d.vector(r, g, b, 0.0))
        indirect_offset = indirect_offset + indirect_step
    end

    return directcolors, indirectcolors
end

function dn_sys:init()
        read_colors_from_files({
            direct      = "/pkg/ant.resources.binary/textures/daynight/day_direct.pngx",
            indirect    = "/pkg/ant.resources.binary/textures/daynight/day_indirect.pngx",
            intensity   = "/pkg/ant.resources.binary/textures/daynight/day_intensity.pngx",
        }, DAYNIGHT.DAY)

        read_colors_from_files({
            direct      = "/pkg/ant.resources.binary/textures/daynight/night_direct.pngx",
            indirect    = "/pkg/ant.resources.binary/textures/daynight/night_indirect.pngx",
            intensity   = "/pkg/ant.resources.binary/textures/daynight/night_intensity.pngx",
        }, DAYNIGHT.NIGHT)
end

local function interpolate_in_array(t, arrays, lerp)
    local v = (#arrays-1) * t
    local x, y = math.modf(v)

    return lerp(arrays[x+1], arrays[x+2], y)
end

local function math3d_interpolate_in_array(t, arrays)
    return interpolate_in_array(t, arrays, math3d.lerp)
end

local function float_interpolate_in_array(t, arrays)
    return interpolate_in_array(t, arrays, mu.lerp)
end

local function clean_rotation_data(r)
    if r.rotate_normal then
        math3d.unmark(r.rotate_normal)
        r.rotate_normal = nil
    end

    if r.direction then
        math3d.unmark(r.direction)
        r.direction = nil
    end
end

local function update_rotation_data(r)
    clean_rotation_data(r)

    local q = r.start_rotator and math3d.quaternion(r.start_rotator) or nil
    local n = r.rotate_axis and math3d.vector(r.rotate_axis) or nil

    r.direction = math3d.mark(q and math3d.transform(q, mc.NXAXIS, 0) or mc.NXAXIS)
    if not n then
        n = q and math3d.transform(q, mc.ZAXIS, 0) or mc.ZAXIS
    end
    n = math3d.normalize(n)
    r.rotate_normal = math3d.mark(n)
end

function dn_sys:entity_init()
    for dne in w:select "INIT daynight:in" do
        local dn = dne.daynight

        if not dn.cycle then
            dn.cycle = 0
        end

        local function init_cycle_value(r)
            update_rotation_data(r)
            if not r.rotate_range then
                r.rotate_range = math.pi
            end
            if not r.intensity then
                r.intensity = ilight.default_intensity "directional"
            end
        end

        init_cycle_value(dn.day)
        init_cycle_value(dn.night)

        if not dn.intensity then
            dn.intensity = ilight.default_intensity "directional"
        end
    end
end

function dn_sys:entity_remove()
    for dne in w:select "REMOVED daynight:in" do
        local dn = dne.daynight

        clean_rotation_data(dn.day)
        clean_rotation_data(dn.night)
    end
end

local function update_cycle(cycle, cyclevalue, COLOR_VALUES)
    --interpolate indirect light color
    local modulate_color = math3d_interpolate_in_array(cycle, COLOR_VALUES.INDIRECT_COLORS)
    local sa = imaterial.system_attribs()
    sa:update("u_indirect_modulate_color", modulate_color)

    --move directional light in cycle
    local dl = w:first "directional_light light:in scene:in"
    if dl then
        local c<const> = math3d_interpolate_in_array(cycle, COLOR_VALUES.DIRECT_COLORS)
        local r, g, b = math3d.index(c, 1, 2, 3)
        ilight.set_color_rgb(dl, r, g, b)

        local intensity<const> = float_interpolate_in_array(cycle, COLOR_VALUES.DIRECT_INTENSITIES)
        ilight.set_intensity(dl, intensity * cyclevalue.intensity)

        if not cyclevalue.disable_rotator then
            local q = math3d.quaternion{axis=cyclevalue.rotate_normal, r=cyclevalue.rotate_range*cycle}
            iom.set_direction(dl, math3d.transform(q, cyclevalue.direction, 0))
        end
        w:submit(dl)
        --print("cycle:", tc, "intensity:", l, "direction:", math3d.tostring(math3d.transform(q, dnl.direction, 0)), "modulate color:", math3d.tostring(modulate_color))
    end
end


local idn = ecs.interface "idaynight"
function idn.update_day_cycle(e, cycle)
    update_cycle(cycle, e.daynight.day, DAYNIGHT.DAY)
end

function idn.update_night_cycle(e, cycle)
    update_cycle(cycle, e.daynight.night, DAYNIGHT.NIGHT)
end

function idn.set_rotation(e, type, start_rotator, rotate_axis)
    w:extend(e, "daynight:in")
    local r = assert(e.daynight[type], "Invalid type")
    r.start_rotator = start_rotator
    r.rotate_axis = rotate_axis
    update_rotation_data(r)
end

--[[test code:
local sys = ecs.system "test_system"
function sys:data_changed()
    local idn = ecs.import.interface "ant.daynight|idaynight"
    local itimer = ecs.import.interface "ant.timer|itimer"
    local dne = w:first "daynight:in"
    local tenSecondMS<const> = 10000
    local cycle = (itimer.current() % tenSecondMS) / tenSecondMS
    idn.update_day_cycle(dne, cycle)

    --
    idn.update_night_cycle(dne, cycle)
end
]]