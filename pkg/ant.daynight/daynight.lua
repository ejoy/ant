local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"

local imaterial = ecs.require "ant.asset|material"
local ilight    = ecs.require "ant.render|light.light"
local iom       = ecs.require "ant.objcontroller|obj_motion"

local dn_sys = ecs.system "daynight_system"
local default_intensity = ilight.default_intensity "directional"
local cached_data_table = {}

local function binary_search(list, t)
    local from, to = 1, #list
    assert(to > 0)
    while from <= to do
        local mid = math.floor((from + to) / 2)
        local t2 = list[mid].time
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
    return math.max(from, 1), math.min(to, #list)
end

local function lerp(list, tick, lerp_function)
    local l, r = binary_search(list, tick)
    local deno = (list[r].time - list[l].time)
    if deno < 10 ^ (-6) then
        return list[l].value
    else
        local lerp_t = (tick - list[l].time) / deno
        return lerp_function(list[l].value, list[r].value, lerp_t)
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

local function get_list(pn, pt)
    local list = {}
    for i = 1, #pt do
        if pn:match("rotator") then
            list[#list+1] = {time = pt[i].time, value = math3d.torotation(math3d.vector(pt[i].value))}
        else
            list[#list+1] = {time = pt[i].time, value = math3d.vector(pt[i].value)}
        end
    end
    return list
end

local idn = {}

function idn.update_cycle(e, cycle)
    local lerp_table = {}
    for pn, pt in pairs(e.daynight) do
        local list = get_list(pn, pt)
        lerp_table[pn] = lerp(list, cycle, math3d.lerp)
    end
    local direct, ambient, rotator = lerp_table["direct"], lerp_table["ambient"], lerp_table["rotator"]
    local dl = w:first "directional_light light:in scene:in"
    if dl then
        local r, g, b, intensity = math3d.index(direct, 1, 2, 3, 4)
        ilight.set_color_rgb(dl, r, g, b)
        ilight.set_intensity(dl, intensity * default_intensity)

        iom.set_direction(dl, math3d.todirection(rotator))
        w:submit(dl)        
    end
    imaterial.system_attrib_update("u_indirect_modulate_color", ambient)
end

function idn.add_property_cycle(e, pn, p)
    local dn = e.daynight
    local current_property = dn[pn]
    local current_number = #current_property
    if current_number >= 6 then return end -- property_number <= 5

    current_property[#current_property+1] = p
    return true
end

function idn.delete_property_cycle(e, pn)
    local dn = e.daynight
    local current_property = dn[pn]
    local current_number = #current_property

    if current_number <= 2 then return end -- property_number >= 2

    table.remove(current_property, current_number)
    return true
end

return idn
