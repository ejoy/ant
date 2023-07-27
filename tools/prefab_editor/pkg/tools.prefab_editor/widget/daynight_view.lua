local ecs = ...
local world = ecs.world
local w = world.w
local event_gizmo   = world:sub {"Gizmo"}
local iom           = ecs.import.interface "ant.objcontroller|iobj_motion"
local idn           = ecs.import.interface "ant.daynight|idaynight"
local mathpkg       = import_package "ant.math"
local mc            = mathpkg.constant
local math3d        = require "math3d"
local uiproperty    = require "widget.uiproperty"
local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local hierarchy     = require "hierarchy_edit"
local prefab_mgr  = ecs.require "prefab_manager"
local serialize = import_package "ant.serialize"
local DaynightView = {}
local dn_idx_table = {}
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
    local e <close> = w:entity(eid, "daynight?in")
    local dn = {}
    for tn, t in pairs(e.daynight) do
        if (not tn:match("direction")) and (not tn:match("rotate_normal")) then
            dn[tn] = t
        end
    end
    local template = hierarchy:get_template(eid)
    local t = template.template
    t.data.daynight = dn

    local lpp = path:parent_path():localpath()
    if not lfs.exists(lpp) then
        lfs.create_directories(lpp)
    end
    local f<close> = lfs.open(lpp / path:filename():string(), "w")
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
        intensity  = uiproperty.Float({label = "Intensity",   dim = 1}),
        direction  = uiproperty.DirectionalArrow({label  = "direction", dim = 3}),
        add_color  = uiproperty.Button({label = "Add Color"}),
        del_color  = uiproperty.Button({label = "Del Color"}),
        add_direction  = uiproperty.Button({label = "Add Direction"}),
        del_direction  = uiproperty.Button({label = "Del Direction"})
    }

    self.direct_base = uiproperty.Group({label = "Direct1"},  self.base.time, self.base.color, self.base.intensity)
    self.ambient_base = uiproperty.Group({label = "Ambient1"},  self.base.time, self.base.color)
    self.rotator_base = uiproperty.Group({label = "Rotator1"},  self.base.time, self.base.direction)
    
    self.direct  = uiproperty.Group({label = "Direct"},  self.base.add_color,  self.base.del_color)
    self.ambient = uiproperty.Group({label = "Ambient"}, self.base.add_color,  self.base.del_color)
    self.rotator = uiproperty.Group({label = "Rotator"}, self.base.add_direction, self.base.del_direction)

    self.save = uiproperty.Button({label = "Save"})
    self.save:set_click(function() self:on_save() end)
    self.daynight = uiproperty.Group({label = "Daynight"}, self.save, self.direct, self.ambient, self.rotator)

end

local label_map = {
    ["direct"] = "Direct", ["ambient"] = "Ambient", ["rotator"] = "Rotator"
}

-- pn: direct ambient rotator
-- t : time color intensity direction
local function get_getter(t, i, pn, e)
    return function()
        local dn = e.daynight
        return dn[pn][t][i]
    end
end

local function get_setter(t, i, pn, e)
    return function (value)
        local dn = e.daynight
        dn[pn][t][i] = value
    end
end

function DaynightView:get_add_click(pn, e)
    return function()
        local default_property
        if pn:match "direct" then
            default_property = {time = 1.0, color = {1.0, 1.0, 1.0}, intensity = 1.0}
        elseif pn:match "ambient"then
            default_property = {time = 1.0, color = {1.0, 1.0, 1.0}}
        elseif pn:match "rotator" then
            default_property = {time = 1.0, direction = {0, 0, 1}}   
        end
        local update_result = idn.add_property_cycle(e, pn, default_property)
        if not update_result then return end
        local dn = e.daynight
        local p = dn[pn]
        local subproperty = self[pn].subproperty
        local time, value = p.time, p.value
        local i = #time
        local label_name = label_map[pn]
        subproperty[#subproperty+1] = uiproperty.Group({label = label_name .. i},  self.base.time, self.base.color)
        local subsubproperty = {
            uiproperty.Float(
                {label = "Time" .. i,   dim = 1, min = 0.00, max = 1.00, speed = 0.02},
                {getter = get_getter("time", i, pn, e), setter = get_setter("time", i, pn, e)}
            ),
        }
        if pn:match("direct") then
            subsubproperty[#subsubproperty+1] = uiproperty.Color(
                {label = "Color" .. i,   dim = 3},
                {getter = get_getter("color", i, pn, e), setter = get_setter("color", i, pn, e)}
            )
            subsubproperty[#subsubproperty+1] = uiproperty.Float(
                {label = "Intensity" .. i,   dim = 1, min = 0.00, max = 5.00, speed = 0.04},
                {getter = get_getter("intensity", i, pn, e), setter = get_setter("intensity", i, pn, e)}
            )                       
        elseif pn:match("ambient") then
            subsubproperty[#subsubproperty+1] = uiproperty.Color(
                {label = "Color" .. i,   dim = 3},
                {getter = get_getter("color", i, pn, e), setter = get_setter("color", i, pn, e)}
            )
        else   
            subsubproperty[#subsubproperty+1] = uiproperty.DirectionalArrow(
                {label = "direction" .. i,   dim = 3},
                {getter = get_getter("direction", i, pn, e), setter = get_setter("direction", i, pn, e)}
            )    
        end
        subproperty[#subproperty]:set_subproperty(subsubproperty) 
        self[pn]:set_subproperty(subproperty)
        self["daynight"]:set_subproperty(self["daynight"].subproperty)     
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
    local subproperty = {}
    local label_name = label_map[pn]
    if pn:match("direct") or pn:match("ambient") then
        subproperty = {
            [1] = uiproperty.Button(
                {label = "Add Color"},
                {click = DaynightView:get_add_click(pn, e)}
            ), 
            [2] = uiproperty.Button(
                {label = "Del Color"},
                {click = DaynightView:get_del_click(pn, e)}
            ), 
        }
    elseif pn:match("rotator") then
        subproperty = {
            [1] = uiproperty.Button(
                {label = "Add Rotator"},
                {click = DaynightView:get_add_click(pn, e)}
            ), 
            [2] = uiproperty.Button(
                {label = "Del Rotator"},
                {click = DaynightView:get_del_click(pn, e)}
            ), 
        }
    end
    for i = 1, #p.time do
        local time, value = p.time, p.value
        subproperty[#subproperty+1] = uiproperty.Group({label = label_name .. i},  self.base.time, self.base.color)
        local subsubproperty = {
            uiproperty.Float(
                {label = "Time" .. i,   dim = 1, min = 0.00, max = 1.00, speed = 0.02},
                {getter = get_getter("time", i, pn, e), setter = get_setter("time", i, pn, e)}
            ),
        }
        if pn:match("direct") then
            subsubproperty[#subsubproperty+1] = uiproperty.Color(
                {label = "Color" .. i,   dim = 3},
                {getter = get_getter("color", i, pn, e), setter = get_setter("color", i, pn, e)}
            )
            subsubproperty[#subsubproperty+1] = uiproperty.Float(
                {label = "Intensity" .. i,   dim = 1, min = 0.00, max = 5.00, speed = 0.04},
                {getter = get_getter("intensity", i, pn, e), setter = get_setter("intensity", i, pn, e)}
            )                       
        elseif pn:match("ambient") then
            subsubproperty[#subsubproperty+1] = uiproperty.Color(
                {label = "Color" .. i,   dim = 3},
                {getter = get_getter("color", i, pn, e), setter = get_setter("color", i, pn, e)}
            )
        else 
            subsubproperty[#subsubproperty+1] = uiproperty.DirectionalArrow(
                {label = "direction" .. i,   dim = 3},
                {getter = get_getter("direction", i, pn, e), setter = get_setter("direction", i, pn, e)}
            )        
        end
        subproperty[#subproperty]:set_subproperty(subsubproperty)  
    end
    return subproperty
end

function DaynightView:get_daynight_cycles(template, e)
    local property_array = {
        [1] = self.save,
    }
    local dn = template.template.data.daynight
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
    local e <close> = w:entity(eid, "daynight?update")
    if e.daynight then
        if #self.daynight.subproperty > 1 then
            self.daynight:set_subproperty(self.daynight.subproperty)
        else
            local template = hierarchy:get_template(eid)
            local property_array = DaynightView:get_daynight_cycles(template, e)
            self.daynight:set_subproperty(property_array)
            self.prefab = template.template.data.prefab 
        end
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