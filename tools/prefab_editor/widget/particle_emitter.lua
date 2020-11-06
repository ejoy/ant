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

function m.update_emitter(update)
    if update then
        m.update_panel(property)
    end
end

function m.create_pro_by_method(pro)
    local data = pro.data
    local sp = {}
    sp[#sp + 1] = uiproperty.Combo("method",
        function(v)
            data.method = v
            pro.dirty = true
            m.update_emitter(true)
        end,
        function() return data.method end,
        method_type)

    if data.method == "around_sphere" then
        sp[#sp + 1] = uiproperty.Float("radius_scale",
            function(...) data_from_ui(data.radius_scale, ...) end,
            function() return data.radius_scale end, 2)
    elseif data.method == "sphere_random" then
        sp[#sp + 1] = uiproperty.Float("longitude",
            function(...) data_from_ui(data.longitude, ...) end,
            function() return data.longitude end, 2)
        sp[#sp + 1] = uiproperty.Float("latitude",
            function(...) data_from_ui(data.latitude, ...) end,
            function() return data.latitude end, 2)
    elseif data.method == "face_axis" then
        sp[#sp + 1] = uiproperty.Float("axis",
            function(...) data_from_ui(data.axis, ...) end,
            function() return data.axis end, 4)
    elseif data.method == "around_box" then
        sp[#sp + 1] = uiproperty.Float("box_range_x",
            function(...) data_from_ui(data.box_range.x, ...) end,
            function() return data.box_range.x end, 2)
        sp[#sp + 1] = uiproperty.Float("box_range_y",
            function(...) data_from_ui(data.box_range.y, ...) end,
            function() return data.box_range.y end, 2)
    elseif data.method == "change_property" then
        sp[#sp + 1] = uiproperty.ResourcePathPro("texture",
            function(value)
                data.properties.s_tex.texture = value
                m.update_emitter()
            end,
            function() return data.properties.s_tex.texture end)
    end
    pro.property = sp
    pro.dirty = false
end

function m.update_panel(props)
    for _, prop in ipairs(props) do
        if prop.class then
            prop:update() 
        else
            if prop.dirty then
                m.create_pro_by_method(prop)
            end
            m.update_panel(prop.property)
        end
    end
end

function m.show_panel(props)
    for _, prop in ipairs(props) do
        if prop.class then
            prop:show()
        else
            if imgui.widget.TreeNode(prop.name, imgui.flags.TreeNode { "DefaultOpen" }) then
                m.show_panel(prop.property)
                imgui.widget.TreePop()
            end
        end
    end
end

local function data_from_ui(target, ...)
    if type(target) == "table" then
        target = {...}
    end
    m.update_emitter()
end

function m.create_emitter_panel(emitter)
    property = {}
    for _, item in ipairs(emitter.attributes) do
        if item.name == "spawn" then
            property[#property + 1] = uiproperty.Int(item.name,
                function(v)
                    item.data.count = v
                    m.update_emitter()
                end,
                function() return item.data.count end)
        elseif item.name == "scale" then
            property[#property + 1] = uiproperty.Float(item.name,
                function(...) data_from_ui(item.data.range, ...) end,
                function() return item.data.range end, 2)
        elseif item.name == "translation"
            or item.name == "orientation"
            or item.name == "material_property" then               
                local sub_property = {name = item.name, property = {}, dirty = false, data = item.data}
                property[#property + 1] = sub_property
                m.create_pro_by_method(sub_property)
        end
    end
    m.update_panel(property)
end

function m.set_emitter(emitter_eid)
    current_emitter_eid = emitter_eid
    m.create_emitter_panel(world[emitter_eid].emitter)
end

local testcolor = {1,0.5,1,1}
local uitestcolor = uiproperty.Color("TestColor",
    function(...) testcolor = {...} end,
    function() return testcolor end)
uitestcolor:update()

function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1] + viewport.WorkSize[1] - uiconfig.PropertyWidgetWidth, viewport.WorkPos[2] + uiconfig.ToolBarHeight, 'F')
    imgui.windows.SetNextWindowSize(uiconfig.PropertyWidgetWidth, viewport.WorkSize[2] - uiconfig.BottomWidgetHeight - uiconfig.ToolBarHeight, 'F')
    for _ in uiutils.imgui_windows("ParticleEmitter", imgui.flags.Window { "NoCollapse", "NoClosed" }) do
        m.show_panel(property)
        uitestcolor:show()
    end
end

return function(w)
    world = w
    return m
end