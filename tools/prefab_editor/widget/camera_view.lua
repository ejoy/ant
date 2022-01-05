local ecs = ...
local world = ecs.world
local w = world.w
ecs.require "widget.base_view"
local icamera     = ecs.import.interface "ant.camera|icamera"
local iom         = ecs.import.interface "ant.objcontroller|iobj_motion"
local camera_mgr  = ecs.require "camera.camera_manager"
local imgui         = require "imgui"
local utils         = require "common.utils"
local math3d        = require "math3d"
local uiproperty    = require "widget.uiproperty"
local BaseView      = require "widget.view_class".BaseView
local CameraView    = require "widget.view_class".CameraView
local hierarchy     = require "hierarchy_edit"


function CameraView:_init()
    BaseView._init(self)
    local property = {}
    self.camera_property    = property
    self.addframe           = uiproperty.Button({label = "AddFrame"}, {
        click = function() self:on_add_frame() end
    })
    self.deleteframe        = uiproperty.Button({label = "DeleteFrame"}, {
        click = function() self:on_delete_frame() end
    })
    self.play               = uiproperty.Button({label = "Play"}, {
        click = function() self:on_play() end
    })
    self.current_frame      = 1
    self.duration           = {}
    self.main_camera_ui     = {false}
end

function CameraView:set_model(eid)
    --FIXME
    self.frames = {} --camera_mgr.get_recorder_frames(eid)
    if not BaseView.set_model(self, eid) then return false end
    local template = hierarchy:get_template(self.e)
    -- if template.template.action and template.template.action.bind_camera and template.template.action.bind_camera.which == "main_queue" then
    --     self.main_camera_ui[1] = true
    -- else
        self.main_camera_ui[1] = false
    -- end
    self.current_frame = 1
    for i, v in ipairs(self.frames) do
        self.duration[i] = {self.frames[i].duration}
    end
    self:update()
    return true
end

function CameraView:on_set_position(...)
    BaseView.on_set_position(self, ...)
    if #self.frames > 0 then
        self.frames[self.current_frame].position = math3d.ref(math3d.vector(...))
    end
    camera_mgr.update_frustrum(self.e)
end

function CameraView:on_get_position()
    if #self.frames > 0 then
        return math3d.totable(self.frames[self.current_frame].position)
    else 
        return math3d.totable(iom.get_position(self.e))
    end
end

function CameraView:on_set_rotate(...)
    BaseView.on_set_rotate(self, ...)
    if #self.frames > 0 then
        self.frames[self.current_frame].rotation = math3d.ref(math3d.quaternion(...))
    end
    camera_mgr.update_frustrum(self.e)
end

function CameraView:on_get_rotate()
    local rad
    if #self.frames > 0 then
        rad = math3d.totable(math3d.quat2euler(self.frames[self.current_frame].rotation))
        return { math.deg(rad[1]), math.deg(rad[2]), math.deg(rad[3]) }
    else
        local r = iom.get_rotation(self.e)
        rad = math3d.totable(math3d.quat2euler(r))
    end
    return { math.deg(rad[1]), math.deg(rad[2]), math.deg(rad[3]) }
end

function CameraView:on_set_scale()

end

function CameraView:on_get_scale()
    return {1, 1, 1}
end

function CameraView:on_get_dist()
    return camera_mgr.get_editor_data(self.e).dist_to_target
end

function CameraView:on_set_fov(value)
    if #self.frames > 0 then
        self.frames[self.current_frame].fov = value
    end
    local template = hierarchy:get_template(self.e)
    template.template.data.camera.frustum.fov = value
    icamera.set_frustum_fov(self.e, value)
    camera_mgr.update_frustrum(self.e)
end
function CameraView:on_get_fov()
    if #self.frames > 0 then
        return self.frames[self.current_frame].fov
    else
        local e = icamera.find_camera(self.e)
        return e.frustum.fov
    end
end
function CameraView:on_set_near(value)
    if #self.frames > 0 then
        self.frames[self.current_frame].n = value
    end
    local template = hierarchy:get_template(self.e)
    template.template.data.camera.frustum.n = value
    icamera.set_frustum_near(self.e, value)
    camera_mgr.update_frustrum(self.e)
end
function CameraView:on_get_near()
    if #self.frames > 0 then
        return self.frames[self.current_frame].n or 1
    else
        local e = icamera.find_camera(self.e)
        return e.frustum.n or 1
    end
end
function CameraView:on_set_far(value)
    if #self.frames > 0 then
        self.frames[self.current_frame].f = value
    end
    local template = hierarchy:get_template(self.e)
    template.template.data.camera.frustum.f = value
    icamera.set_frustum_far(self.e, value)
    camera_mgr.update_frustrum(self.e)
end
function CameraView:on_get_far()
    if #self.frames > 0 then
        return self.frames[self.current_frame].f or 100
    else
        local e = icamera.find_camera(self.e)
        return e.frustum.f
    end
end
function CameraView:update()
    BaseView.update(self)
    for _, pro in ipairs(self.camera_property) do
        pro:update() 
    end
end

function CameraView:on_play()
    camera_mgr.play_recorder(self.e)
end

function CameraView:on_add_frame()
    --FIXME: recorder must be serialized, so we need to build the relationship of recorder entity and camera entity
    --       or recorder as camera component's attribute
    assert(false, "need rewrite")
    local new_idx = self.current_frame + 1
    camera_mgr.add_recorder_frame(self.e, new_idx)
    self.current_frame = new_idx
    local frames = camera_mgr.get_recorder_frames(self.e)
    if not self.duration[1] then
        self.duration[1] = {frames[1].duration}
    end
    self.duration[new_idx] = {frames[new_idx].duration}
    self:update()
end

function CameraView:on_delete_frame()
    camera_mgr.delete_recorder_frame(self.e, self.current_frame)
    table.remove(self.duration, self.current_frame)
    local frames = camera_mgr.get_recorder_frames(self.e)
    if self.current_frame > #frames then
        self.current_frame = #frames
        self:update()
    end
end

function CameraView:show()
    BaseView.show(self)
    if imgui.widget.TreeNode("Camera", imgui.flags.TreeNode { "DefaultOpen" }) then
        imgui.widget.PropertyLabel("MainCamera")
        if imgui.widget.Checkbox("##MainCamera", self.main_camera_ui) then
            local template = hierarchy:get_template(self.e)
            if self.main_camera_ui[1] then
                if not template.template.action then
                    template.template.action = {}
                end
                template.template.action.bind_camera = {which = "main_queue"}
            else
                if template.template.action and template.template.action.bind_camera then
                    template.template.action.bind_camera = nil
                end
            end
        end

        for _, pro in ipairs(self.camera_property) do
            pro:show() 
        end
        imgui.cursor.Separator()
        self.addframe:show()
        if #self.frames > 1 then
            imgui.cursor.SameLine()
            self.deleteframe:show()
            imgui.cursor.SameLine()
            self.play:show()
        end
        
        if #self.frames > 0 then
            imgui.cursor.Separator()
            if imgui.table.Begin("CameraViewtable", 2, imgui.flags.Table {'Resizable', 'ScrollY'}) then
                imgui.table.SetupColumn("FrameIndex", imgui.flags.TableColumn {'NoSort', 'WidthFixed', 'NoResize'}, -1, 0)
                imgui.table.SetupColumn("Duration", imgui.flags.TableColumn {'NoSort', 'WidthStretch'}, -1, 1)
                imgui.table.HeadersRow()
                for i, v in ipairs(self.frames) do
                    --imgui.table.NextRow()
                    imgui.table.NextColumn()
                    --imgui.table.SetColumnIndex(0)
                    if imgui.widget.Selectable(i, self.current_frame == i) then
                        self.current_frame = i
                        camera_mgr.set_frame(self.e, i)
                        self:update()
                    end
                    imgui.table.NextColumn()
                    --imgui.table.SetColumnIndex(1)
                    if imgui.widget.DragFloat("##"..i, self.duration[i]) then
                        self.frames[i].duration = self.duration[i][1]
                    end
                end
                imgui.table.End()
            end
        end
        
        imgui.widget.TreePop()
    end
end

function CameraView:has_scale()
    return false
end

return CameraView