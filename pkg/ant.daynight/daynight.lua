local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mc, mu    = mathpkg.constant, mathpkg.util
local math3d    = require "math3d"

local imaterial = ecs.import.interface "ant.asset|imaterial"
local ilight    = ecs.import.interface "ant.render|ilight"
local iom       = ecs.import.interface "ant.objcontroller|iobj_motion"

local dn_sys = ecs.system "daynight_system"
local default_intensity = ilight.default_intensity "directional"
local cached_data_table = {}

local function binary_search(time_table, t)
    local from, to = 1, #time_table
    assert(to > 0)
    while from <= to do
        local mid = math.floor((from + to) / 2)
        local t2 = time_table[mid]
        if t == t2 then
            return mid, mid
        elseif t < t2 then
            to = mid - 1
        else
            from = mid + 1
        end
    end

    if from > to then
        local v = to
        to = from
        from = v
    end
    return math.max(from, 1), math.min(to, #time_table)
end

local function lerp(l, r, t, time_table, lerp_table, lerp_function, tn)
    local deno = (time_table[r] - time_table[l])
    if deno < 10 ^ (-6) then
        if tn:match("direction") then
            return math3d.torotation(math3d.vector(lerp_table[l]))
        elseif tn:match("intensity") then
            return lerp_table[l]
        else
            return math3d.vector(lerp_table[l]) end
    end
    local lerp_t = (t - time_table[l]) / (time_table[r] - time_table[l])
    if tn:match("direction") then
        local lq = math3d.torotation(math3d.vector(lerp_table[l]))
        local rq = math3d.torotation(math3d.vector(lerp_table[r]))
        return lerp_function(lq, rq, lerp_t)
    else if tn:match("intensity") then
        return lerp_function(lerp_table[l], lerp_table[r], lerp_t)
    end
        return lerp_function(math3d.vector(lerp_table[l]), math3d.vector(lerp_table[r]), lerp_t)
    end
end

local function reserve_data()
    local dl = w:first "directional_light light:in scene:in"
    if dl then
        cached_data_table.directional_color = math3d.mark(math3d.vector(dl.light.color))
        cached_data_table.directional_intensity = dl.light.intensity
    end
end

local function restore_data()
    local dl = w:first "directional_light light:in scene:in"
    if dl then
        local dl_color = cached_data_table.directional_color
        ilight.set_color_rgb(dl, math3d.index(dl_color, 1, 2, 3))
        ilight.set_intensity(dl, cached_data_table.directional_intensity)
        math3d.unmark(dl_color)
    end 
end

function dn_sys:entity_init()
    for dne in w:select "INIT daynight:in" do
        reserve_data()
    end 
end

function dn_sys:entity_remove()
    for dne in w:select "REMOVED daynight:in" do
        restore_data()
    end
end

local idn = ecs.interface "idaynight"
function idn.update_cycle(e, cycle)
    local direct, ambient, rotator, intensity
    for propertry_name, property_table in pairs(e.daynight) do
        local time = property_table.time
        local lidx, ridx = binary_search(time, cycle)
        if propertry_name:match("direct") then
            local color, inten = property_table.color, property_table.intensity
            direct = lerp(lidx, ridx, cycle, time, color, math3d.lerp, "color")
            intensity = lerp(lidx, ridx, cycle, time, inten, mu.lerp, "intensity")
        elseif propertry_name:match("ambient") then
            local color = property_table.color
            ambient = lerp(lidx, ridx, cycle, time, color, math3d.lerp, "color")
        elseif propertry_name:match("rotator") then
            local direction = property_table.direction
            rotator = lerp(lidx, ridx, cycle, time, direction, math3d.lerp, "direction")
        end
    end

    local dl = w:first "directional_light light:in scene:in"
    if dl then
        local r, g, b = math3d.index(direct, 1, 2, 3)
        ilight.set_color_rgb(dl, r, g, b)
        ilight.set_intensity(dl, intensity * default_intensity)

        iom.set_direction(dl, math3d.todirection(rotator))
        w:submit(dl)        
    end
    local sa = imaterial.system_attribs()
    sa:update("u_indirect_modulate_color", ambient)
end

function idn.add_property_cycle(e, property_name, property)
    local dn = e.daynight
    local current_property = dn[property_name]
    local time = current_property.time
    if #time >= 6 then return end -- property_number <= 5
    time[#time+1] = property.time
    if property_name:match "rotator" then
        local direction = current_property.direction
        direction[#direction+1] = property.direction
    else
        local color = current_property.color
        color[#color+1] = property.color
        if property_name:match "direct" then
            local intensity = current_property.intensity
            intensity[#intensity+1] = property.intensity
        end 
    end 
    return true
end

function idn.delete_property_cycle(e, property_name)
    local dn = e.daynight
    local current_property = dn[property_name]
    local time = current_property.time
    local current_num = #time
    if current_num <=2 then return end -- property_number >=2
    for _ ,t in pairs(current_property) do
        table.remove(t, current_num)
    end
    return true
end
