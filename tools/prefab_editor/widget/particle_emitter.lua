local imgui     = require "imgui"
local math3d    = require "math3d"
local hierarchy = require "hierarchy"
local uiconfig  = require "widget.config"
local uiutils   = require "widget.utils"
local uiproperty    = require "widget.uiproperty"

local world

local m = {}

local born_pro = {
    Scale = {0.15, 0.28},
    Velocity = {1.0, 1.0, 1.0},
    LifeTime = {5.0},
    Direction = {1.0, 1.0, 1.0},
    EmitterType = {1},
    Name = "No Name",
    MaterialFile = "test material",
    TextureFile = "test texture",
}


local method_type = {"around_sphere", "sphere_random", "face_axis", "around_box", "change_property"}

local current_emitter_eid

local property = {}

local function update_emitter()

end

local function data_from_ui(target, ...)
    if type(target) == "table" then
        target = {...}
    end
    update_emitter()
end

local function create_pro_by_method(data)
    local sp = {}
    sp[#sp + 1] = uiproperty.Combo({label = "method", options = method_type},
        {
            setter = function(v)
                data.method = v
                update_emitter()
            end,
            getter = function() return data.method end
        })

    if data.method == "around_sphere" then
        sp[#sp + 1] = uiproperty.Float({label = "radius_scale", dim = 2},
            {
                setter = function(...) data_from_ui(data.radius_scale, ...) end,
                getter = function() return data.radius_scale end
            })
    elseif data.method == "sphere_random" then
        sp[#sp + 1] = uiproperty.Float({label = "longitude", dim = 2},
            {
                setter = function(...) data_from_ui(data.longitude, ...) end,
                getter = function() return data.longitude end
            })
        sp[#sp + 1] = uiproperty.Float({label = "latitude", dim = 2},
            {
                setter = function(...) data_from_ui(data.latitude, ...) end,
                getter = function() return data.latitude end
            })
    elseif data.method == "face_axis" then
        sp[#sp + 1] = uiproperty.Float({label = "axis", dim = 4},
            {
                setter = function(...) data_from_ui(data.axis, ...) end,
                getter = function() return data.axis end
            })
    elseif data.method == "around_box" then
        sp[#sp + 1] = uiproperty.Float({label = "box_range_x", dim = 2},
            {
                setter = function(...) data_from_ui(data.box_range.x, ...) end,
                getter = function() return data.box_range.x end
            })
        sp[#sp + 1] = uiproperty.Float({label = "box_range_y", dim = 2},
            {
                setter = function(...) data_from_ui(data.box_range.y, ...) end,
                getter = function() return data.box_range.y end
            })
    elseif data.method == "change_property" then
        sp[#sp + 1] = uiproperty.ResourcePath({label = "texture"},
            {
                setter = function(value)
                    data.properties.s_tex.texture = value
                    update_emitter()
                end,
                getter = function() return data.properties.s_tex.texture end
            })
    end
    return sp
end

local function update_panel(props)
    for _, prop in ipairs(props) do
        prop:update()
    end
end

local function show_panel(props)
    for _, prop in ipairs(props) do
        prop:show()
    end
end

local function create_emitter_panel(emitter)
    property = {}
    for _, item in ipairs(emitter.attributes) do
        if item.name == "spawn" then
            property[#property + 1] = uiproperty.Int({label = item.name},
                {
                    setter = function(v)
                        item.data.count = v
                        update_emitter()
                    end,
                    getter = function() return item.data.count end
                })
        elseif item.name == "scale" then
            property[#property + 1] = uiproperty.Float({label = item.name, dim = 2},
                {
                    setter = function(...) data_from_ui(item.data.range, ...) end,
                    getter = function() return item.data.range end
                })
        elseif item.name == "translation"
            or item.name == "orientation"
            or item.name == "material_property" then
                property[#property + 1] = uiproperty.Group({label = item.name}, create_pro_by_method(item.data))       
        end
    end
    update_panel(property)
end

function m.set_emitter(emitter_eid)
    current_emitter_eid = emitter_eid
    create_emitter_panel(world[emitter_eid].emitter)
end

local testcolor = {1, 0.5, 1, 1}
local uitestcolor = uiproperty.Color({label = "TestColor", dim = 4},
                    {
                        setter = function(...) testcolor = {...} end,
                        getter = function() return testcolor end
                    })
uitestcolor:update()

function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1] + viewport.WorkSize[1] - uiconfig.PropertyWidgetWidth, viewport.WorkPos[2] + uiconfig.ToolBarHeight, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.PropertyWidgetWidth, viewport.WorkSize[2] - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, 'F')
    for _ in uiutils.imgui_windows("ParticleEmitter", imgui.flags.Window { "NoCollapse", "NoClosed" }) do
        show_panel(property)
        --uitestcolor:show()
    end
end

return function(w)
    world = w
    return m
end