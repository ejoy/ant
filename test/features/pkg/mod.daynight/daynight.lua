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

local DIRECT_COLORS, INDIRECT_COLORS = {}, {}

local dn_sys = ecs.system "daynight_system"

local DEFAULT_DIRECTIONAL_LIGHT_INTENSITY

local function read_colors_from_files()

    local function read_image_content(p)
        local f<close> = fs.open(fs.path(p), "rb")
        local c = f:read "a"
        return image.parse(c, true)
    end
    do
        local direct_info, direct_c         = read_image_content "/pkg/mod.daynight/assets/light/direct.pngx"
        local indirect_info, indirect_c     = read_image_content "/pkg/mod.daynight/assets/light/indirect.pngx"
        local intensity_info, intensity_c   = read_image_content "/pkg/mod.daynight/assets/light/intensity.pngx"

        assert(direct_info.depth == 1 and (not direct_info.cubemap))
        assert(indirect_info.depth == 1 and (not indirect_info.cubemap))

        assert(indirect_info.width == direct_info.width and indirect_info.width == intensity_info.width)

        local direct_step<const>    = direct_info.bitsPerPixel // 8
        local indirect_step<const>  = indirect_info.bitsPerPixel // 8
        local intensity_step<const> = intensity_info.bitsPerPixel // 8

        local function to_float(v, ...)
            if v then
                return v / 255.0, to_float(...)
            end
        end

        --we just need a row
        local direct_offset, indirect_offset, intensity_offset = 1, 1, 1
        for iw=1, direct_info.width do
            local r, g, b = to_float(('BBB'):unpack(direct_c, direct_offset))
            local intensity = to_float(('B'):unpack(intensity_c, intensity_offset))
            DIRECT_COLORS[iw] = math3d.ref(math3d.vector(r, g, b, intensity))

            local ir, ig, ib = to_float(('BBB'):unpack(indirect_c, indirect_offset))
            INDIRECT_COLORS[iw] = math3d.ref(math3d.vector(ir, ig, ib, 0.0))
            direct_offset = direct_offset + direct_step
            intensity_offset = intensity_offset + intensity_step
            indirect_offset = indirect_offset + indirect_step
        end
    end
end

function dn_sys:init()
    DEFAULT_DIRECTIONAL_LIGHT_INTENSITY = ilight.default_intensity "directional"

    read_colors_from_files()
end

local function interpolate_in_array(t, arrays)
    local v = (#arrays-1) * t
    local x, y = math.modf(v)

    return math3d.lerp(arrays[x+1], arrays[x+2], y)
end

function dn_sys:entity_init()
    for dne in w:select "INIT daynight:in" do
        local dn = dne.daynight

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

local function update_daynight_value(dne)
    local dn = dne.daynight
    local tc = dn.cycle

    --interpolate indirect light color
    local modulate_color = interpolate_in_array(tc, INDIRECT_COLORS)
    local sa = imaterial.system_attribs()
    sa:update("u_indirect_modulate_color", modulate_color)

    --move directional light in cycle
    local dl = w:first "directional_light light:in scene:in"
    if dl then
        local dnl = dn.light

        do
            local c<const> = interpolate_in_array(tc, DIRECT_COLORS)
            local r, g, b, i = math3d.index(c, 1, 2, 3, 4)
            ilight.set_color_rgb(dl, r, g, b)

            ilight.set_intensity(dl, i * DEFAULT_DIRECTIONAL_LIGHT_INTENSITY)
        end

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
function idn.update_cycle(e, cycle)
    e.daynight.cycle = cycle
    update_daynight_value(e)
end

function idn.set_rotation_data(start_dir, normal)
    local dne = w:first "daynight:in"
    local dnl = dne.daynight.light

    math3d.unmark(dnl.normal)
    dnl.normal = math3d.mark(math3d.vector(normal))

    math3d.unmark(dnl.start_dir)
    dnl.start_dir = math3d.mark(math3d.vector(start_dir))
end