local ecs = ...
local world = ecs.world
local w = world.w
local event_gizmo   = world:sub {"Gizmo"}
local iom           = ecs.require "ant.objcontroller|obj_motion"
local mathpkg       = import_package "ant.math"
local mc            = mathpkg.constant
local math3d        = require "math3d"
local uiproperty    = require "widget.uiproperty"
local hierarchy     = require "hierarchy_edit"
local BaseView = {}
local render_layer_name = {"foreground", "opacity", "background", "translucent", "decal_stage", "ui_stage"}
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
        name     = uiproperty.EditText({label = "Name"}),
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
    self.base.name:set_setter(function(value) self:on_set_name(value) end)      
    self.base.name:set_getter(function() return self:on_get_name() end)
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
    if not eid then
        self.eid = nil
        return
    end
    self.eid = eid
    local template = hierarchy:get_template(self.eid)
    self.is_prefab = template and template.filename
    local property = {}
    property[#property + 1] = self.base.name
    property[#property + 1] = self.base.tag
    local e <close> = world:entity(self.eid, "scene?in render_layer?in")
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
        if template.template and template.template.data.bounding then
            self.base.aabbmin:set_visible(true)
            self.base.aabbmax:set_visible(true)
        else
            self.base.create_aabb:set_visible(true)
        end
    end
    self.general_property:set_subproperty(property)
    BaseView:update()
end

function BaseView:on_get_prefab()
    local template = hierarchy:get_template(self.eid)
    if template and template.filename then
        return template.filename
    end
end

function BaseView:on_set_preview(value)
    local template = hierarchy:get_template(self.eid)
    template.editor = value
end

function BaseView:on_get_preview()
    local template = hierarchy:get_template(self.eid)
    return template.editor
end

function BaseView:on_set_name(value)
    local template = hierarchy:get_template(self.eid)
    template.template.data.name = value
    local e <close> = world:entity(self.eid, "name:out")
    e.name = value
    world:pub {"EntityEvent", "name", self.eid, value}
end

function BaseView:on_get_name()
    local e <close> = world:entity(self.eid, "name?in")
    if type(e.name) == "number" then
        return tostring(e.name)
    end
    return e.name or ""
end

function BaseView:on_set_tag(value)
    -- local template = hierarchy:get_template(self.eid)
    -- local tags = {}
    -- value:gsub('[^|]*', function (w) tags[#tags+1] = w end)
    -- template.template.data.tag = tags
    -- world:pub {"EntityEvent", "tag", self.eid, tags}
end

function BaseView:on_get_tag()
    -- local template = hierarchy:get_template(self.eid)
    -- if not template or not template.template then return "" end
    -- local tags = template.template.data.tag
    -- if type(tags) == "table" then
    --     return table.concat(tags, "|")
    -- end
    -- return tags or ""
    return ""
end

function BaseView:on_set_position(value)
    local template = hierarchy:get_template(self.eid)
    local t = {value[1], value[2], value[3]}
    if template.template then
        world:pub {"EntityEvent", "move", self.eid, template.template.data.scene.t or {0,0,0}, t}
        template.template.data.scene.t = t
    else
        local e <close> = world:entity(self.eid)
        world:pub {"EntityEvent", "move", self.eid, math3d.tovalue(iom.get_position(e)), t}
    end
end

function BaseView:on_get_position()
    local template = hierarchy:get_template(self.eid)
    if template.template then
        return template.template.data.scene.t or {0,0,0}
    else
        local e <close> = world:entity(self.eid)
        return math3d.totable(iom.get_position(e))
    end
end

function BaseView:on_set_rotate(value)
    local template = hierarchy:get_template(self.eid)
    world:pub {"EntityEvent", "rotate", self.eid, { math.rad(value[1]), math.rad(value[2]), math.rad(value[3]) }, {value[1], value[2], value[3]}}
    if template.template then
        template.template.data.scene.r = math3d.tovalue(math3d.quaternion{math.rad(value[1]), math.rad(value[2]), math.rad(value[3])})
    end
end

function BaseView:on_get_rotate()
    local template = hierarchy:get_template(self.eid)
    local r
    if template.template then
        r = template.template.data.scene.r or {0,0,0,1}
    else
        local e <close> = world:entity(self.eid)
        r = iom.get_rotation(e)
    end
    local rad = math3d.tovalue(math3d.quat2euler(r))
    local raweuler = { math.deg(rad[1]), math.deg(rad[2]), math.deg(rad[3]) }
    return raweuler
end

function BaseView:on_set_scale(value)
    local template = hierarchy:get_template(self.eid)
    local s = {value[1], value[2], value[3]}
    if template.template then
        world:pub {"EntityEvent", "scale", self.eid, template.template.data.scene.s or {1,1,1}, s}
        template.template.data.scene.s = s
    else
        local e <close> = world:entity(self.eid)
        world:pub {"EntityEvent", "scale", self.eid, math3d.tovalue(iom.get_scale(e)), s}
    end
end

function BaseView:on_get_scale()
    local template = hierarchy:get_template(self.eid)
    if template.template then
        local s = template.template.data.scene.s
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
    local template = hierarchy:get_template(self.eid)
    if template.template then
        if template.template.data.bounding then
            local tv = {value[1], value[2], value[3]}
            template.template.data.bounding.aabb.min = tv
            local e <close> = world:entity(self.eid, "bounding?in")
            local bounding = e.bounding
            if bounding then
                local aabbmax = {0,0,0}
                if bounding.aabb and bounding.aabb ~= mc.NULL then
                    aabbmax = math3d.tovalue(math3d.array_index(bounding.aabb, 2)) or {}
                    math3d.isvalid(bounding.aabb)
                    math3d.unmark(bounding.aabb)
                end
                bounding.aabb = math3d.mark(math3d.aabb(tv, aabbmax))
                world:pub {"UpdateAABB", self.eid}
            end
        end
    end
end

function BaseView:on_get_aabbmin()
    local template = hierarchy:get_template(self.eid)
    if template.template then
        local bounding = template.template.data.bounding
        if bounding then
            return bounding.aabb.min
        end
    end
    return {-1,-1,-1}
end

function BaseView:on_set_aabbmax(value)
    local template = hierarchy:get_template(self.eid)
    if template.template then
        if template.template.data.bounding then
            local tv = {value[1], value[2], value[3]}
            template.template.data.bounding.aabb.max = tv
            local e <close> = world:entity(self.eid, "bounding?in")
            local bounding = e.bounding
            if bounding then
                local aabbmin = {0,0,0}
                if bounding.aabb and bounding.aabb ~= mc.NULL then
                    aabbmin = math3d.tovalue(math3d.array_index(bounding.aabb, 1))
                    math3d.isvalid(bounding.aabb)
                    math3d.unmark(bounding.aabb)
                end
                bounding.aabb = math3d.mark(math3d.aabb(aabbmin, tv))
                world:pub {"UpdateAABB", self.eid}
            end
        end
    end
end

function BaseView:on_get_aabbmax()
    local template = hierarchy:get_template(self.eid)
    if template.template then
        local bounding = template.template.data.bounding
        if bounding then
            return bounding.aabb.max
        end
    end
    return {1,1,1}
end

function BaseView:on_get_render_layer()
    local e <close> = world:entity(self.eid, "render_layer?in")
    return e.render_layer
end

local irl = ecs.require "ant.render|render_layer"
function BaseView:on_set_render_layer(value)
    local e <close> = world:entity(self.eid)
    irl.set_layer(e, value)
end

function BaseView:create_aabb()
    local tpl = hierarchy:get_template(self.eid)
    if tpl.template then
        local e <close> = world:entity(self.eid, "bounding?in")
        local bounding = e.bounding
        local min = {-1, -1, -1}
        local max = {1, 1, 1}
        if bounding and bounding.aabb ~= mc.NULL then
            min = math3d.tovalue(math3d.array_index(bounding.aabb, 1))
            max = math3d.tovalue(math3d.array_index(bounding.aabb, 2))
        end
        tpl.template.data.bounding = {aabb ={ min = {min[1], min[2], min[3]}, max = {max[1], max[2], max[3]} }}
        self.base.create_aabb:set_visible(false)
        self.base.delete_aabb:set_visible(true)
        self.base.aabbmin:set_visible(true)
        self.base.aabbmax:set_visible(true)
        self.base.aabbmin:update()
        self.base.aabbmax:update()
    end
end

function BaseView:delete_aabb()
    local tpl = hierarchy:get_template(self.eid)
    if tpl.template then
        tpl.template.data.bounding = nil
        self.base.create_aabb:set_visible(true)
        self.base.delete_aabb:set_visible(false)
        self.base.aabbmin:set_visible(false)
        self.base.aabbmax:set_visible(false)
        local e <close> = world:entity(self.eid, "bounding?in")
        local bounding = e.bounding
        if bounding.aabb and bounding.aabb ~= mc.NULL then
            bounding.aabb = mc.NULL
        else
            math3d.unmark(bounding.aabb)
        end
        world:pub {"UpdateAABB", self.eid}
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

function BaseView:show()
    if not self.eid then return end
    for _, _, _, _ in event_gizmo:unpack() do
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