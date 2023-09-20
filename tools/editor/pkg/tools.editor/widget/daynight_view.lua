local ecs = ...
local world = ecs.world
local w = world.w
local idn           = ecs.require "ant.daynight|daynight"
local uiproperty    = require "widget.uiproperty"
local fs        = require "filesystem"
local lfs       = require "bee.filesystem"
local hierarchy     = require "hierarchy_edit"
local prefab_mgr  = ecs.require "prefab_manager"
local serialize = import_package "ant.serialize"
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
    local dn = {}
    for tn, t in pairs(e.daynight) do
        if (not tn:match("direction")) and (not tn:match("rotate_normal")) then
            dn[tn] = t
        end
    end
    local info = hierarchy:get_node_info(eid)
    local t = info.template
    t.data.daynight = dn
    dn.path = idn.get_current_path()
    local lpp = path:parent_path():localpath()
    if not lfs.exists(lpp) then
        lfs.create_directories(lpp)
    end
    local f<close> = assert(io.open((lpp / path:filename()._value):string(), "w"))
    f:write(serialize.stringify(t))
end

local function reload()
    prefab_mgr:save()
    prefab_mgr:reload()
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
        direction  = uiproperty.DirectionalArrow({label  = "Direction", dim = 3}),
        add_color  = uiproperty.Button({label = "Add Color"}),
        del_color  = uiproperty.Button({label = "Del Color"}),
        add_direction  = uiproperty.Button({label = "Add Direction"}),
        del_direction  = uiproperty.Button({label = "Del Direction"})
    }
    
    self.direct  = uiproperty.Group({label = "Direct"},  self.base.add_color,  self.base.del_color)
    self.ambient = uiproperty.Group({label = "Ambient"}, self.base.add_color,  self.base.del_color)
    self.rotator = uiproperty.Group({label = "Rotator"}, self.base.add_direction, self.base.del_direction)

    self.save = uiproperty.Button({label = "Save"})
    self.save:set_click(function() self:on_save() end)
    self.daynight = uiproperty.Group({label = "Daynight"}, self.save, self.direct, self.ambient, self.rotator)

end

local pn_label = {
    direct  = {label_upper = "Direct",  label_add = "Add Color",   label_del = "Del Color",   default_property = {time = 1, value = {1, 1, 1, 1}}},
    ambient = {label_upper = "Ambient", label_add = "Add Color",   label_del = "Del Color",   default_property = {time = 1, value = {1, 1, 1}}},
    rotator = {label_upper = "Rotator", label_add = "Add Rotator", label_del = "Del Rotator", default_property = {time = 1, value = {0, 0, 1}}},
}

-- pn: direct ambient rotator
-- t : time value
local function get_getter(pn, i, t, e)
    return function()
        local dn = e.daynight
        if t:match("color") then
            return {dn[pn][i]["value"][1], dn[pn][i]["value"][2], dn[pn][i]["value"][3]}
        elseif t:match("intensity") then
            return dn[pn][i]["value"][4]
        elseif t:match("direction") then
            return dn[pn][i]["value"]
        elseif t:match("time") then
            return dn[pn][i]["time"]
        end
    end
end

local function get_setter(pn, i, t, e)
    return function (value)
        local dn = e.daynight

        if t:match("color") then
            dn[pn][i]["value"][1], dn[pn][i]["value"][2], dn[pn][i]["value"][3] = value[1], value[2], value[3]
        elseif t:match("intensity") then
            dn[pn][i]["value"][4] = value
        elseif t:match("direction") then
            dn[pn][i]["value"] = value
        elseif t:match("time") then
            dn[pn][i]["time"] = value
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
    else 
        subsubproperty[#subsubproperty+1] = uiproperty.DirectionalArrow(
            {label = "direction" .. i,   dim = 3},
            {getter = get_getter(pn, i, "direction", e), setter = get_setter(pn, i, "direction", e)}
        )        
    end
    subproperty[#subproperty]:set_subproperty(subsubproperty)
end

function DaynightView:get_add_click(pn, e)
    return function()
        local default_property = pn_label[pn].default_property
        local update_result = idn.add_property_cycle(e, pn, default_property)
        if not update_result then return end
        local dn = e.daynight
        local p = dn[pn]
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
        [1] = uiproperty.Button({label = pn_label[pn].label_add},{click = DaynightView:get_add_click(pn, e)}),
        [2] = uiproperty.Button({label = pn_label[pn].label_del},{click = DaynightView:get_del_click(pn, e)}),
    }
    for i = 1, #p do
        DaynightView:add_subsubproperty(subproperty, i, pn, e)
    end
    return subproperty
end

function DaynightView:get_daynight_cycles(info, e)
    local property_array = {
        [1] = self.save,
    }
    local dn = info.template.data.daynight
    dn.path = nil
    for pn, p in pairs(dn) do
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
        local info = hierarchy:get_node_info(eid)
        local property_array = DaynightView:get_daynight_cycles(info, e)
        self.daynight:set_subproperty(property_array)
        self.prefab = idn.get_current_path()
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