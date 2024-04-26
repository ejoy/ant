local ecs = ...
local world = ecs.world

local mathpkg       = import_package "ant.math"
local mc            = mathpkg.constant
local iom           = ecs.require "ant.objcontroller|obj_motion"
local irl		    = ecs.require "ant.render|render_layer.render_layer"
local hierarchy     = ecs.require "hierarchy_edit"
local math3d        = require "math3d"
local uiproperty    = require "widget.uiproperty"

local BaseView = {}
local render_layer_name = {"foreground", "opacity", "background", "translucent", "decal", "ui"}
function BaseView:_init()
    if self.inited then
        return
    end
    self.inited = true
    self.has_rotate = true
    self.has_scale = true
    self.base = {
        script   = uiproperty.ResourcePath({label = "Script", extension = ".lua"}),
        prefab   = uiproperty.EditText({label = "Prefabe", readonly = true}),
        preview  = uiproperty.Bool({label = "OnlyPreview"}),
        tag      = uiproperty.EditText({label = "Tag"}),
        position = uiproperty.Float({label = "Position", dim = 3, speed = 0.1}),
        rotate   = uiproperty.Float({label = "Rotate", dim = 3}),
        scale    = uiproperty.Float({label = "Scale", dim = 3, speed = 0.05}),
        aabbmin  = uiproperty.Float({label = "AABB Min", dim = 3, speed = 0.05}),
        aabbmax  = uiproperty.Float({label = "AABB Max", dim = 3, speed = 0.05}),
        create_aabb  = uiproperty.Button({label="Create AABB"}),
        delete_aabb  = uiproperty.Button({label="Delete AABB"}),
        render_layer = uiproperty.Combo({label="Render Layer", options = render_layer_name})
    }
    self.general_property = uiproperty.Group({label = "General"}, self.base)
    --
    self.base.prefab:set_getter(function() return self:on_get_prefab() end)
    self.base.preview:set_setter(function(value) self:on_set_preview(value) end)      
    self.base.preview:set_getter(function() return self:on_get_preview() end)
    self.base.tag:set_setter(function(value) self:on_set_tag(value) end)      
    self.base.tag:set_getter(function() return self:on_get_tag() end)
    self.base.position:set_setter(function(value) self:on_set_position(value) end)
    self.base.position:set_getter(function() return self:on_get_position() end)
    self.base.rotate:set_setter(function(value) self:on_set_rotate(value) end)
    self.base.rotate:set_getter(function() return self:on_get_rotate() end)
    self.base.scale:set_setter(function(value) self:on_set_scale(value) end)
    self.base.scale:set_getter(function() return self:on_get_scale() end)
    self.base.aabbmin:set_setter(function(value) self:on_set_aabbmin(value) end)
    self.base.aabbmin:set_getter(function() return self:on_get_aabbmin() end)
    self.base.aabbmax:set_setter(function(value) self:on_set_aabbmax(value) end)
    self.base.aabbmax:set_getter(function() return self:on_get_aabbmax() end)
    self.base.create_aabb:set_click(function() self:create_aabb() end)
    self.base.delete_aabb:set_click(function() self:delete_aabb() end)
    self.base.render_layer:set_getter(function() return self:on_get_render_layer() end)
    self.base.render_layer:set_setter(function(value) self:on_set_render_layer(value) end)
end

function BaseView:set_eid(eid)
    if self.eid == eid then
        return
    end
    self.eid = eid
    if not eid then
        return
    end
    local info = hierarchy:get_node_info(self.eid)
    self.is_prefab = info and info.filename
    local property = {}
    -- property[#property + 1] = self.base.name
    property[#property + 1] = self.base.tag
    local e <close> = world:entity(self.eid, "scene?in render_layer?in camera?in")
    if e.scene then
        property[#property + 1] = self.base.position
        if self.has_rotate then
            property[#property + 1] = self.base.rotate
        end
        if self.has_scale then
            property[#property + 1] = self.base.scale
        end
        if e.render_layer then
            property[#property + 1] = self.base.render_layer
        end
        property[#property + 1] = self.base.aabbmin
        property[#property + 1] = self.base.aabbmax
        property[#property + 1] = self.base.create_aabb
        property[#property + 1] = self.base.delete_aabb
        self.base.aabbmin:set_visible(false)
        self.base.aabbmax:set_visible(false)
        self.base.create_aabb:set_visible(false)
        self.base.delete_aabb:set_visible(false)
        if info then
            if info.template and info.template.data.bounding then
                self.base.aabbmin:set_visible(true)
                self.base.aabbmax:set_visible(true)
                self.base.delete_aabb:set_visible(true)
            else
                self.base.create_aabb:set_visible(not e.camera)
            end
        end
    end
    self.general_property:set_subproperty(property)
    BaseView:update()
end

function BaseView:on_get_prefab()
    local info = hierarchy:get_node_info(self.eid)
    if info and info.filename then
        return info.filename
    end
end

function BaseView:on_set_preview(value)
    local info = hierarchy:get_node_info(self.eid)
    info.editor = value
end

function BaseView:on_get_preview()
    local info = hierarchy:get_node_info(self.eid)
    return info.editor
end

function BaseView:on_set_tag(value)
    local info = hierarchy:get_node_info(self.eid)
    if not info or not info.template then
        return
    end
    local tags = {}
    value:gsub('[^|]*', function (w) tags[#tags+1] = w end)
    local oldtags = info.template.tag
    info.template.tag = tags
    world:pub {"EntityEvent", "tag", self.eid, oldtags, tags}
end

function BaseView:on_get_tag()
    local info = hierarchy:get_node_info(self.eid)
    if not info or not info.template then
        return ""
    end
    local tags = info.template.tag
    return tags and table.concat(tags, "|") or ""
end

function BaseView:on_set_position(value)
    local info = hierarchy:get_node_info(self.eid)
    local t = {value[1], value[2], value[3]}
    if info and info.template then
        world:pub {"EntityEvent", "move", self.eid, info.template.data.scene.t or {0,0,0}, t}
        info.template.data.scene.t = t
    else
        local e <close> = world:entity(self.eid)
        world:pub {"EntityEvent", "move", self.eid, math3d.tovalue(iom.get_position(e)), t}
    end
end

function BaseView:on_get_position()
    local info = hierarchy:get_node_info(self.eid)
    if info and info.template then
        return info.template.data.scene.t or {0,0,0}
    else
        local e <close> = world:entity(self.eid)
        return math3d.totable(iom.get_position(e))
    end
end

function BaseView:on_set_rotate(value)
    local info = hierarchy:get_node_info(self.eid)
    world:pub {"EntityEvent", "rotate", self.eid, { math.rad(value[1]), math.rad(value[2]), math.rad(value[3]) }, {value[1], value[2], value[3]}}
    if info and info.template then
        info.template.data.scene.r = math3d.tovalue(math3d.quaternion{math.rad(value[1]), math.rad(value[2]), math.rad(value[3])})
    end
end

function BaseView:on_get_rotate()
    local info = hierarchy:get_node_info(self.eid)
    local r
    if info and info.template then
        r = info.template.data.scene.r or {0,0,0,1}
    else
        local e <close> = world:entity(self.eid)
        r = iom.get_rotation(e)
    end
    local rad = math3d.tovalue(math3d.quat2euler(r))
    local raweuler = { math.deg(rad[1]), math.deg(rad[2]), math.deg(rad[3]) }
    return raweuler
end

function BaseView:on_set_scale(value)
    local info = hierarchy:get_node_info(self.eid)
    local s = {value[1], value[2], value[3]}
    if info and info.template then
        world:pub {"EntityEvent", "scale", self.eid, info.template.data.scene.s or {1,1,1}, s}
        info.template.data.scene.s = s
    else
        local e <close> = world:entity(self.eid)
        world:pub {"EntityEvent", "scale", self.eid, math3d.tovalue(iom.get_scale(e)), s}
    end
end

function BaseView:on_get_scale()
    local info = hierarchy:get_node_info(self.eid)
    if info and info.template then
        local s = info.template.data.scene.s
        if s then
            return type(s) == "table" and s or {s, s, s}
        else
            return {1,1,1}
        end
    else
        local e <close> = world:entity(self.eid)
        return math3d.tovalue(iom.get_scale(e))
    end
end

function BaseView:on_set_aabbmin(value)
    local info = hierarchy:get_node_info(self.eid)
    if info and info.template then
        if info.template.data.bounding then
            local tv = {value[1], value[2], value[3]}
            info.template.data.bounding.aabb[1] = tv
            local e <close> = world:entity(self.eid, "bounding:update scene_needchange?out")
            local bounding = e.bounding
            if bounding then
                local aabbmax = info.template.data.bounding.aabb[2]
                if bounding.aabb and bounding.aabb ~= mc.NULL then
                    local rmax = math3d.tovalue(math3d.array_index(bounding.aabb, 2)) or {}
                    aabbmax = {rmax[1], rmax[2], rmax[3]}
                    math3d.unmark(bounding.aabb)
                end
                bounding.aabb = math3d.mark(math3d.aabb(math3d.vector(tv), math3d.vector(aabbmax)))
                e.scene_needchange = true
                world:pub { "UpdateAABB", {self.eid}}
                world:pub { "Patch", "", self.eid, "/data/bounding/aabb", {tv, aabbmax} }
            end
        end
    end
end

function BaseView:on_get_aabbmin()
    local info = hierarchy:get_node_info(self.eid)
    if info and info.template then
        local bounding = info.template.data.bounding
        if bounding then
            return bounding.aabb[1]
        end
    end
    return {-1,-1,-1}
end

function BaseView:on_set_aabbmax(value)
    local info = hierarchy:get_node_info(self.eid)
    if info and info.template then
        if info.template.data.bounding then
            local tv = {value[1], value[2], value[3]}
            info.template.data.bounding.aabb[2] = tv
            local e <close> = world:entity(self.eid, "bounding:update scene_needchange?out")
            local bounding = e.bounding
            if bounding then
                local aabbmin = info.template.data.bounding.aabb[1]
                if bounding.aabb and bounding.aabb ~= mc.NULL then
                    local rmin = math3d.tovalue(math3d.array_index(bounding.aabb, 1))
                    aabbmin = {rmin[1], rmin[2], rmin[3]}
                    math3d.unmark(bounding.aabb)
                end
                bounding.aabb = math3d.mark(math3d.aabb(math3d.vector(aabbmin), math3d.vector(tv)))
                e.scene_needchange = true
                world:pub { "UpdateAABB", {self.eid}}
                world:pub { "Patch", "", self.eid, "/data/bounding/aabb", {aabbmin, tv} }
            end
        end
    end
end

function BaseView:on_get_aabbmax()
    local info = hierarchy:get_node_info(self.eid)
    if info and info.template then
        local bounding = info.template.data.bounding
        if bounding then
            return bounding.aabb[2]
        end
    end
    return {1,1,1}
end

function BaseView:on_get_render_layer()
    local e <close> = world:entity(self.eid, "render_layer?in")
    return e.render_layer
end

function BaseView:on_set_render_layer(value)
    local e <close> = world:entity(self.eid)
    irl.set_layer(e, value)
end

function BaseView:create_aabb()
    local info = hierarchy:get_node_info(self.eid)
    if info and info.template then
        local e <close> = world:entity(self.eid, "bounding:update scene_needchange?out")
        e.scene_needchange = true
        local min = {-1, -1, -1}
        local max = {1, 1, 1}
        local bounding = e.bounding
        if bounding and bounding.aabb ~= mc.NULL then
            min = math3d.tovalue(math3d.array_index(bounding.aabb, 1))
            max = math3d.tovalue(math3d.array_index(bounding.aabb, 2))
        end
        info.template.data.bounding = {aabb = {{min[1], min[2], min[3]}, {max[1], max[2], max[3]}}}
        bounding.aabb = math3d.mark(math3d.aabb(math3d.vector(min), math3d.vector(max)))
        self.base.create_aabb:set_visible(false)
        self.base.delete_aabb:set_visible(true)
        self.base.aabbmin:set_visible(true)
        self.base.aabbmax:set_visible(true)
        self.base.aabbmin:update()
        self.base.aabbmax:update()
        world:pub { "UpdateAABB", {self.eid} }
        world:pub { "Patch", "", self.eid, "/data/bounding/aabb", {min, max} }
    end
end

function BaseView:delete_aabb()
    local info = hierarchy:get_node_info(self.eid)
    if info and info.template then
        info.template.data.bounding = nil
        self.base.create_aabb:set_visible(true)
        self.base.delete_aabb:set_visible(false)
        self.base.aabbmin:set_visible(false)
        self.base.aabbmax:set_visible(false)
        local e <close> = world:entity(self.eid, "bounding?in scene_needchange?out")
        e.scene_needchange = true
        local bounding = e.bounding
        if bounding.aabb and bounding.aabb ~= mc.NULL then
            bounding.aabb = mc.NULL
        end
        world:pub { "UpdateAABB", {self.eid}}
        world:pub { "Patch", "", self.eid, "/data/bounding/aabb" }
    end
end

function BaseView:reset_disable()
    self.has_rotate = true
    self.has_scale = true
end

function BaseView:disable_rotate()
    self.has_rotate = false
end

function BaseView:disable_scale()
    self.has_scale = false
end

function BaseView:update()
    if not self.eid then return end
    if self.is_prefab then
        self.base.prefab:update()
        self.base.preview:update()
    end
    self.general_property:update()
end

local event_gizmo = world:sub {"Gizmo"}
local event_copy_maincamera = world:sub {"CopyMainCamera"}
local irq = ecs.require "ant.render|renderqueue"
function BaseView:show()
    if not self.eid then return end
    for _, _, _, _ in event_gizmo:unpack() do
        self:update()
    end
    for _ in event_copy_maincamera:unpack() do
        local camera <close> = world:entity(irq.main_camera(), "camera:in scene:in")
        -- local srt = camera.scene
        local r, t = iom.get_rotation(camera), iom.get_position(camera)
        local rad = math3d.tovalue(math3d.quat2euler(r))
        self:on_set_rotate({ math.deg(rad[1]), math.deg(rad[2]), math.deg(rad[3]) })
        self:on_set_position({math3d.index(t, 1, 2, 3)})
        local e <close> = world:entity(self.eid)
        iom.set_rotation(e, r)
        iom.set_position(e, t)
        self:update()
    end
    if self.is_prefab then
        self.base.prefab:show()
        self.base.preview:show()
    end
    self.general_property:show()
    
end

return function ()
    BaseView:_init()
    return BaseView
end