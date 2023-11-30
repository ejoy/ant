local ecs = ...
local world = ecs.world
local w = world.w
local idn           = ecs.require "ant.daynight|daynight"
local uiproperty    = require "widget.uiproperty"
local fs        = require "filesystem"
local lfs       = require "bee.filesystem"
local hierarchy     = require "hierarchy_edit"
local daynightui    = ecs.require "daynight_ui"
local prefab_mgr  = ecs.require "prefab_manager"
local serialize = import_package "ant.serialize"
local math3d    = require "math3d"
local DaynightView = {}
local function check_relative_path(path, basepath)
    if path:is_relative() then
        if not fs.exists(basepath / path) then
            error(("base path: %s, relative resource path: %s, is not valid"):format(basepath:string(), path:string()))
        end
    else
        if not fs.exists(path) then
            error(("Invalid resource path:%s"):format(path:string()))
        end
    end
end

local function save_prefab(eid, path)
    local e <close> = world:entity(eid, "daynight?in")
    local dn = {raw = {}, path = e.daynight.path, type = e.daynight.type}
    for tn, t in pairs(e.daynight.rt) do
        local tt = {}
        for _, pt in ipairs(t) do
            tt[#tt+1] = {time = pt.time, value = math3d.tovalue(pt.value)}
        end
        dn.raw[tn] = tt
    end
    local info = hierarchy:get_node_info(eid)
    local t = info.template
    t.data.daynight = dn
    local file_path = fs.path(path):localpath():string()
    local f<close> = assert(io.open(file_path, "w"))
    f:write(serialize.stringify(t))
end

local function reload()
    prefab_mgr:save()
    --prefab_mgr:reload()
end


function DaynightView:on_save()
    local filepath = fs.path(self.prefab)
    check_relative_path(filepath, prefab_mgr:get_current_filename())
    save_prefab(self.eid, filepath)
    reload()
end

function DaynightView:_init()
    if self.inited then
        return
    end
    self.inited = true

    self.base = {
        time       = uiproperty.Float({label = "Time",   dim = 1}),
        color      = uiproperty.Color({label = "Color",  dim = 3}),
        arrow  = uiproperty.DirectionalArrow({label  = "Arrow", dim = 3}),
        direction = uiproperty.Float({label = "Direction",   dim = 3}),
        add_color  = uiproperty.Button({label = "Add Color"}),
        del_color  = uiproperty.Button({label = "Del Color"}),
        add_direction  = uiproperty.Button({label = "Add Direction"}),
        del_direction  = uiproperty.Button({label = "Del Direction"})
    }
    
    self.direct  = uiproperty.Group({label = "Direct"},  self.base.add_color,  self.base.del_color)
    self.ambient = uiproperty.Group({label = "Ambient"}, self.base.add_color,  self.base.del_color)
    self.rotator = uiproperty.Group({label = "Rotator"}, self.base.add_direction, self.base.del_direction)
--[[     self.cycle   = uiproperty.Float({label = "Cycle",   dim = 1}) ]]

    self.save = uiproperty.Button({label = "Save"})
    self.save:set_click(function() self:on_save() end)
    self.daynight = uiproperty.Group({label = "Daynight"}, self.save, self.direct, self.ambient, self.rotator)

end

local pn_label = {
    direct  = {label_upper = "Direct",  label_add = "Add Color",   label_del = "Del Color",   default_property = {time = 1, value = math3d.mark(math3d.vector(1, 1, 1, 1))}},
    ambient = {label_upper = "Ambient", label_add = "Add Color",   label_del = "Del Color",   default_property = {time = 1, value = math3d.mark(math3d.vector(1, 1, 1))}},
    rotator = {label_upper = "Rotator", label_add = "Add Rotator", label_del = "Del Rotator", default_property = {time = 1, value = math3d.mark(math3d.torotation(math3d.vector(0, 0, 1)))}},
}

-- pn: direct ambient rotator
-- t : time value
local function get_getter(pn, i, t, e)
    return function()
        local dn_rt = e.daynight.rt
        if t:match "color" then
            local c1, c2, c3 = math3d.index(dn_rt[pn][i].value, 1, 2, 3)
            return {c1, c2, c3}
        elseif t:match "intensity" then
            return math3d.index(dn_rt[pn][i].value, 4)
        elseif t:match "arrow" then
            local dx, dy, dz = math3d.index(math3d.todirection(dn_rt[pn][i].value), 1, 2, 3)
            return {dx, dy, dz}
        elseif t:match "direction" then
            local dx, dy, dz = math3d.index(math3d.todirection(dn_rt[pn][i].value), 1, 2, 3)
            return {dx, dy, dz}
        elseif t:match "time" then
            return dn_rt[pn][i].time
        end
    end
end

local function get_setter(pn, i, t, e)
    return function (value)
        local dn_rt = e.daynight.rt
        if t:match("color") then
            for ii = 1, 3 do
                math3d.unmark(dn_rt[pn][i].value)
                dn_rt[pn][i].value = math3d.mark(math3d.set_index(dn_rt[pn][i].value, ii, value[ii]))
            end
        elseif t:match("intensity") then
            math3d.unmark(dn_rt[pn][i].value)
            dn_rt[pn][i].value = math3d.mark(math3d.set_index(dn_rt[pn][i].value, 4, value))
        elseif t:match("arrow") then
            math3d.unmark(dn_rt[pn][i].value)
            dn_rt[pn][i].value = math3d.mark(math3d.torotation(math3d.vector(value)))
        elseif t:match("direction") then
            math3d.unmark(dn_rt[pn][i].value)
            dn_rt[pn][i].value = math3d.mark(math3d.torotation(math3d.normalize(math3d.vector(value))))
        elseif t:match("time") then
            dn_rt[pn][i].time = value
        end
    end
end

function DaynightView:add_subsubproperty(subproperty, i, pn, e)
    local label_name = pn_label[pn].label_upper
    subproperty[#subproperty+1] = uiproperty.Group({label = label_name .. i},  self.base.time)
    local subsubproperty = {
        uiproperty.Float(
            {label = "Time" .. i,   dim = 1, min = 0.00, max = 1.00, speed = 0.02},
            {getter = get_getter(pn, i, "time", e), setter = get_setter(pn, i, "time", e)}
        ),
    }
    if pn:match("direct") then
        subsubproperty[#subsubproperty+1] = uiproperty.Color(
            {label = "Color" .. i,   dim = 3},
            {getter = get_getter(pn, i, "color", e), setter = get_setter(pn, i, "color", e)}
        )
        subsubproperty[#subsubproperty+1] = uiproperty.Float(
            {label = "Intensity" .. i,   dim = 1, min = 0.00, max = 5.00, speed = 0.04},
            {getter = get_getter(pn, i, "intensity", e), setter = get_setter(pn, i, "intensity", e)}
        )                       
    elseif pn:match("ambient") then
        subsubproperty[#subsubproperty+1] = uiproperty.Color(
            {label = "Color" .. i,   dim = 3},
            {getter = get_getter(pn, i, "color", e), setter = get_setter(pn, i, "color", e)}
        )
        subsubproperty[#subsubproperty+1] = uiproperty.Float(
            {label = "Intensity" .. i,   dim = 1, min = 0.00, max = 5.00, speed = 0.04},
            {getter = get_getter(pn, i, "intensity", e), setter = get_setter(pn, i, "intensity", e)}
        )  
    else 
        subsubproperty[#subsubproperty+1] = uiproperty.DirectionalArrow(
            {label = "Arrow" .. i,   dim = 3},
            {getter = get_getter(pn, i, "arrow", e), setter = get_setter(pn, i, "arrow", e)}
        )
        subsubproperty[#subsubproperty+1] = uiproperty.Float(
            {label = "Direction" .. i,   dim = 3, min = -5.00, max = 5.00, speed = 0.04},
            {getter = get_getter(pn, i, "direction", e), setter = get_setter(pn, i, "direction", e)}
        )       
    end
    subproperty[#subproperty]:set_subproperty(subsubproperty)
end

function DaynightView:get_add_click(pn, e)
    local function get_default_property()
        if pn:match "direct" then
            return {time = 1, value = math3d.mark(math3d.vector(1, 1, 1, 1))}
        elseif pn:match "ambient" then
            return {time = 1, value = math3d.mark(math3d.vector(1, 1, 1))}
        elseif pn:match "rotator" then
            return {time = 1, value = math3d.mark(math3d.torotation(math3d.vector(0, 0, 1)))}
        end
    end
    return function()
        local default_property = get_default_property()
        local update_result = idn.add_property_cycle(e, pn, default_property)
        if not update_result then return end
        local dn_rt = e.daynight.rt
        local p = dn_rt[pn]
        local subproperty = self[pn].subproperty
        local i = #p
        DaynightView:add_subsubproperty(subproperty, i, pn, e)
    end
end

function DaynightView:get_del_click(pn, e)
    return function()
        local update_result = idn.delete_property_cycle(e, pn)
        if not update_result then return end
        local subproperty = self[pn].subproperty
        table.remove(subproperty, #subproperty)          
    end
end

function DaynightView:get_subproperty(e, pn, p)
    local subproperty = {
        uiproperty.Button({label = pn_label[pn].label_add},{click = DaynightView:get_add_click(pn, e)}),
        uiproperty.Button({label = pn_label[pn].label_del},{click = DaynightView:get_del_click(pn, e)}),
    }
    for i = 1, #p do
        DaynightView:add_subsubproperty(subproperty, i, pn, e)
    end
    return subproperty
end

function DaynightView:get_daynight_cycles(e)
    
    local function cycle_getter()
        return function()
            return daynightui.get_daynight_cycle()
        end
    end

    local function cycle_setter()
        return function(value)
            daynightui.set_daynight_cycle(value)
        end
    end

    local property_array = {
        self.save,
        uiproperty.Float(
            {label = "Cycle",   dim = 1, min = 1.00, max = 1000.00, speed = 0.02},
            {getter = cycle_getter(), setter = cycle_setter()}
        )
    }
    for pn, p in pairs(e.daynight.rt) do
        property_array[#property_array+1] = self[pn]
        local subproperty = DaynightView:get_subproperty(e, pn, p)
        property_array[#property_array]:set_subproperty(subproperty)
    end
    return property_array
end

function DaynightView:set_eid(eid)
    if self.eid == eid then
        return
    end
    if not eid then
        self.eid = nil
        return
    end
    local e <close> = world:entity(eid, "daynight?update")
    if e.daynight then
        local property_array = DaynightView:get_daynight_cycles(e)
        self.daynight:set_subproperty(property_array)
        self.prefab = e.daynight.path
        self.type = e.daynight.type
    else
        self.eid = nil
        return
    end
    self.eid = eid
    DaynightView:update()
end

function DaynightView:update()
    if not self.eid then return end
    self.daynight:update() 
end

function DaynightView:show()
    if not self.eid then return end
    self.daynight:show()
end

return function ()
    DaynightView:_init()
    return DaynightView
end