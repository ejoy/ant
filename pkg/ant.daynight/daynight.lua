local ecs   = ...
local world = ecs.world
local w     = world.w

local math3d    = require "math3d"

local imaterial = ecs.require "ant.asset|material"
local ilight    = ecs.require "ant.render|light.light"
local iom       = ecs.require "ant.objcontroller|obj_motion"

local dn_sys = ecs.system "daynight_system"
local default_intensity = ilight.default_intensity "directional"

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

local function slerp(list, tick)

    local function get_hdir(ldir, rdir)
        local hdir = math3d.normalize(math3d.add(ldir, rdir))
        if math3d.dot(hdir, math3d.vector(0, 0, 1)) >=0 then
            return math3d.vector(0, 0, 1)
        else
            return math3d.vector(0, 0, -1)
        end
    end

    local l, r = binary_search(list, tick)
    local deno = (list[r].time - list[l].time)
    local ldir = math3d.todirection(list[l].value)
    local rdir = math3d.todirection(list[r].value)
    local hdir = get_hdir(ldir, rdir)
    if deno < 10 ^ (-6) then
        return list[l].value, math3d.vector(0, 0, 1)
    else
        local lerp_t = (tick - list[l].time) / deno
        local lrot = math3d.quaternion(hdir, ldir)
        local rrot = math3d.quaternion(hdir, rdir)
        return math3d.slerp(lrot, rrot, lerp_t), hdir
    end
end

local function lerp(list, tick)
    local l, r = binary_search(list, tick)
    local deno = (list[r].time - list[l].time)
    if deno < 10 ^ (-6) then
        return list[l].value
    else
        local lerp_t = (tick - list[l].time) / deno
        return math3d.lerp(list[l].value, list[r].value, lerp_t)
    end
end

local function build_daynight_runtime(dne)
    local daynight = dne.daynight
    local daynight_raw, daynight_rt = daynight.raw, {}
    for pn, pt in pairs(daynight_raw) do
        local tt = {}
        for _, v in ipairs(pt) do
            if pn:match "rotator" then
                tt[#tt+1] = {time = v.time, value = math3d.mark(math3d.quaternion(v.value))}
            else
                tt[#tt+1] = {time = v.time, value = math3d.mark(math3d.vector(v.value))}
            end
        end
        daynight_rt[pn] = tt
    end
    daynight.rt = daynight_rt
end

function dn_sys:entity_init()
    for dne in w:select "INIT daynight:update daynight_changed?out" do
        dne.daynight_changed = true
    end

    for dne in w:select "daynight_changed:update daynight:update" do
        build_daynight_runtime(dne)
        dne.daynight_changed = nil
    end
end

function dn_sys:entity_remove()
end

local idn = {}

function idn.update_cycle(e, cycle)
    local lerp_table = {}
    local hdir
    for pn, pt in pairs(e.daynight.rt) do
        if pn:match("rotator") then
            lerp_table[pn], hdir = slerp(pt, cycle)
        else
            lerp_table[pn] = lerp(pt, cycle) 
        end
    end
    local direct, ambient, rotator = lerp_table["direct"], lerp_table["ambient"], lerp_table["rotator"]
    local dl = w:first "directional_light light:in scene:in"
    if dl then
        local r, g, b, intensity = math3d.index(direct, 1, 2, 3, 4)
        ilight.set_color_rgb(dl, r, g, b)
        ilight.set_intensity(dl, intensity * default_intensity)
        iom.set_direction(dl, math3d.normalize(math3d.transform(rotator, hdir, 1)))
        w:submit(dl)        
    end
    local ar, ag, ab, ai = math3d.index(ambient, 1, 2, 3, 4)
    local ambient_rgb = math3d.vector(ar*ai, ag*ai, ab*ai)
    imaterial.system_attrib_update("u_indirect_modulate_color", ambient_rgb)
end

function idn.add_property_cycle(e, pn, p)
    local dn_rt = e.daynight.rt
    local current_property = dn_rt[pn]
    local current_number = #current_property
    if current_number >= 25 then return end -- property_number <= 9

    current_property[#current_property+1] = p
    return true
end

function idn.delete_property_cycle(e, pn)
    local dn_rt = e.daynight.rt
    local current_property = dn_rt[pn]
    local current_number = #current_property

    if current_number <= 2 then return end -- property_number >= 2

    table.remove(current_property, current_number)
    return true
end

return idn
