local ImGui     = require "imgui"
local ImGuiWidgets = require "imgui.widgets"
local assetmgr  = import_package "ant.asset"
local uiconfig  = require "widget.config"
local fs        = require "filesystem"
local lfs       = require "bee.filesystem"
local global_data = require "common.global_data"

local utils     = require "common.utils"
local rc        = import_package "ant.compile_resource"
local class     = utils.class 

local PropertyBase = class "PropertyBase"

function PropertyBase:_init(config, modifier)
    self.label      = config.label
    self.readonly   = config.readonly
    self.disable    = config.disable or false
    self.visible    = config.visible or true
    self.id         = config.id
    self.dim        = config.dim or 1
    self.mode       = config.mode
    self.sameline   = config.sameline
    self.modifier   = modifier or {}
    self.uidata     = {speed = config.speed, min = config.min, max = config.max, flags = config.flags}
end

function PropertyBase:set_getter(getter)
    self.modifier.getter = getter
end

function PropertyBase:set_setter(setter)
    self.modifier.setter = setter
end

function PropertyBase:is_disable()
    return self.disable
end

function PropertyBase:set_disable(v)
    self.disable = v
end

function PropertyBase:is_visible()
    return self.visible
end

function PropertyBase:set_visible(v)
    self.visible = v
end

function PropertyBase:get_id()
    return self.id
end

function PropertyBase:update()
    local value = self.modifier.getter()
    if type(value) == "table" then
        for i = 1, self.dim do
            self.uidata[i] = value[i]
        end
    else
        self.uidata[1] = value
    end
end

function PropertyBase:show_label()
    if self.mode == nil or self.mode == "label_left" then
        ImGuiWidgets.PropertyLabel(self.label)
    end
end

function PropertyBase:get_label()
    if self.mode == "label_right" then
        return self.label
    else
        return "##" .. self.label
    end
end

function PropertyBase:widget()
end

function PropertyBase:show()
    if self:is_visible() then
        self:show_label()
        if self:widget() then
            local d = self.uidata
            if self.dim == 1 then
                self.modifier.setter(d[1])
            else
                self.modifier.setter(d)
            end
        end
    end
end

local DirectionalArrow = class("DirectionalArrow", PropertyBase)
function DirectionalArrow:widget()
    return ImGuiWidgets.DirectionalArrow(self:get_label(), self.uidata)
end

local Int = class("Int", PropertyBase)
local DragInt = {
    ImGui.DragInt,
    ImGui.DragInt2,
    ImGui.DragInt3,
    ImGui.DragInt4
}
function Int:widget()
    return DragInt[self.dim](self:get_label(), self.uidata)
end

local Float = class("Float", PropertyBase)
local DragFloat = {
    ImGui.DragFloat,
    ImGui.DragFloat2,
    ImGui.DragFloat3,
    ImGui.DragFloat4
}
function Float:widget()
    return DragFloat[self.dim](self:get_label(), self.uidata)
end

local Bool = class("Bool", PropertyBase)
function Bool:widget()
    return ImGui.Checkbox(self:get_label(), self.uidata)
end

local Color = class("Color", PropertyBase)
local ColorEdit = {
    "",
    "",
    ImGui.ColorEdit3,
    ImGui.ColorEdit4
}
function Color:widget()
    return ColorEdit[self.dim](self:get_label(), self.uidata)
end

local Combo = class("Combo", PropertyBase)
function Combo:_init(config, modifier)
    PropertyBase._init(self, config, modifier)
    self.options = config.options
end

function Combo:set_options(options)
    local d = self.uidata
    for i=1, #options do
        d[i] = options[i]
    end
    d[#options+1] = nil
    self.options = options
end

function Combo:show()
    if self:is_visible() then
        self:show_label()
        ImGui.PushID(tostring(self))
        local current_option = self.modifier.getter()
        if ImGui.BeginCombo(self:get_label(), current_option, self.uidata.flags) then
            for _, option in ipairs(self.options) do
                if ImGui.SelectableEx(option, current_option == option) then
                    self.modifier.setter(option)
                end
            end
            ImGui.EndCombo()
        end
        ImGui.PopID()
    end
end

local Text = class("Text", PropertyBase)
function Text:widget()
    return ImGui.Text(self.uidata.text)
end

local EditText = class("EditText", PropertyBase)


function EditText:_init(config, modifier)
    PropertyBase._init(self, config, modifier)
    self.uidata.text = ImGui.StringBuf()
end

function EditText:widget()
    if self.readonly then
        return ImGui.Text(tostring(self.uidata.text))
    else
        -- it will change self.uidata.text as userdata
        return ImGui.InputText(self:get_label(), self.uidata.text)
    end
end

function EditText:update()
    self.uidata.text = ImGui.StringBuf(self.modifier.getter())
end

function EditText:value()
    return tostring(self.uidata.text)
end

function EditText:show()
    if self:is_visible() then
        ImGuiWidgets.PropertyLabel(self.label)
        if self:widget() then
            self.modifier.setter(tostring(self.uidata.text))
        end
    end
end

local ResourcePath      = class("ResourcePath", EditText)

function ResourcePath:_init(config, modifier)
    EditText._init(self, config, modifier)
    self.extension = config.extension
end

function ResourcePath:update()
    local path = self.modifier.getter()
    self.path = path
    self.uidata.text = ImGui.StringBuf(path)
end

local uiutils       = require "widget.utils"

local stringify     = import_package "ant.serialize".stringify

function ResourcePath:on_dragdrop()
    
end

function ResourcePath:get_extension()
    return self.extension
end

function ResourcePath:show()
    if not self:is_visible() then
        return
    end
    -- ImGui.Text(self.label)
    -- ImGui.SameLine(uiconfig.PropertyIndent)
    ImGuiWidgets.PropertyLabel(self.label)
    self:widget()
    if ImGui.BeginDragDropTarget() then
        local payload = ImGui.AcceptDragDropPayload("DragFile")
        if payload then
            local relative_path = lfs.path(payload)--lfs.relative(lfs.path(payload), fs.path "/":localpath())
            local extension = relative_path:extension()
            if extension == self.extension then
                local path_str = tostring(payload)
                self.path = path_str
                self.uidata.text = ImGui.StringBuf(path_str)
                self.modifier.setter(path_str)
                self:on_dragdrop()
            end
        end
        ImGui.EndDragDropTarget()
    end
end

function ResourcePath:get_path()
    return self.path
end

function ResourcePath:get_metadata()
    return self.metadata
end

local TextureResource  = class("TextureResource", ResourcePath)
function TextureResource:_init(config, modifier)
    ResourcePath._init(self, config, modifier)
    self.extension = ".texture"
end
local serialize = import_package "ant.serialize"

function TextureResource:do_update()
    if #self.path <= 0 then return end
    local r = {}
    self.path:gsub('[^|]*', function (w) r[#r+1] = w end)
    if #r > 1 then
        self.metadata = serialize.load(self.path)
        if self.metadata.path[1] ~= '/' then
            self.metadata.path = r[1] .. "/images/" .. fs.path(self.metadata.path):filename():string()
        end
    else
        self.metadata = utils.readtable(self.path)
    end
    self.runtimedata = assetmgr.resource(self.path)
    if not self.uidata2 then
        self.uidata2 = ImGui.StringBuf(self.metadata.path)
    else
        self.uidata2:Assgin(self.metadata.path)
    end
end

function TextureResource:update()
    ResourcePath.update(self)
    self:do_update()
    if string.find(self.metadata.path, "|") then
        self.readonly = true
    else
        self.readonly = false
    end
end

function TextureResource:on_dragdrop()
    self:do_update()
end
local glb_path
local image_path
local filelist = {}
local selected_file

function TextureResource:set_file(path)
    self.metadata.path = path
    self.uidata2:Assgin(self.metadata.path)
    if string.sub(path, -4) ~= ".dds" then
        local t = assetmgr.resource(path, { compile = true })
        self.runtimedata._data.handle = t.handle
    end
end

function TextureResource:show()
    if not self:is_visible() then
        return 
    end
    ResourcePath.show(self)
    if not self.runtimedata then return end
    --if not self.runtimedata._data.handle then return end
    if ImGui.BeginTable("##TextureTable" .. self.label, 2, ImGui.TableFlags {}) then
        ImGui.TableSetupColumnEx("ImagePreview", ImGui.TableColumnFlags {'WidthFixed'}, 64.0)
        ImGui.TableSetupColumnEx("ImagePath", ImGui.TableColumnFlags {'NoHide', 'WidthStretch'}, 1.0)
        ImGui.TableNextColumn()
        if self.runtimedata._data.handle then
            ImGui.Image(assetmgr.textures[self.runtimedata._data.id], uiconfig.PropertyImageSize, uiconfig.PropertyImageSize)
        end
        ImGui.TableNextColumn()
        ImGui.PushItemWidth(-1)
        ImGui.InputText("##" .. self.metadata.path .. self.label, self.uidata2)
        ImGui.PopItemWidth()
        if ImGui.BeginDragDropTarget() then
            local payload = ImGui.AcceptDragDropPayload("DragFile")
            if payload then
                local path = fs.path(payload);
                if path:extension() == ".png" or path:extension() == ".dds" then
                    self:set_file(tostring(path))
-- TODO: do not use unload, use assetmgr.flush instead				
--                  assetmgr.unload(self.path)
                end
            end
            ImGui.EndDragDropTarget()
        end

        if not self.readonly then
            ImGui.PushID("Save" .. self.label)
            if ImGui.Button("Save") then
                if not self.path:find("|", 1, true) then
                    utils.write_file(self.path, stringify(self.metadata))
                end
            end
            ImGui.PopID()
            ImGui.SameLine()
        end
        
        ImGui.PushID("Save As" .. self.label)
        if ImGui.Button("Save As") then
            local path = uiutils.get_saveas_path("Texture", "texture")
            if path then
                --path = tostring(lfs.relative(lfs.path(path), fs.path "/":localpath()))
                utils.write_file(path, stringify(self.metadata))
            end
        end
        ImGui.PopID()
        ImGui.SameLine()
        
        if ImGui.Button("Select...") then
            local glb_filename = uiutils.get_open_file_path("Textures", "glb")
            if glb_filename then
                local vp = global_data:lpath_to_vpath(glb_filename)
                assert(vp)
                glb_path = "/" .. vp
                rc.compile(glb_path)
                image_path = rc.compile(glb_path .. "/images")
                ImGui.OpenPopup("select_image")
            end
        end
        ImGui.SameLine()
        if image_path then
            if ImGui.BeginPopup("select_image") then
                for path in fs.pairs(image_path) do
                    if path:extension() == ".png" or path:extension() == ".dds" then
                        local filename = path:filename():string()
                        if ImGui.SelectableEx(filename, false) then
                            self:set_file(glb_path .. "/images/" .. filename)
                            image_path = nil
                        end
                    end
                end
                ImGui.EndPopup()
            end
        end
        ImGui.EndTable()
    end
end


local Button = class("Button", PropertyBase)
local button_id = 0
function Button:_init(config, modifier, width, height)
    PropertyBase._init(self, config, modifier)
    button_id = button_id + 1
    self.button_id = button_id
    local d = self.uidata
    d.width, d.height = width, height
end

function Button:update()
end

function Button:set_click(click)
    self.modifier.click = click
end

function Button:show()
    if self:is_visible() then
        ImGui.PushID("ui_button_id" .. self.button_id)
        ImGui.BeginDisabled(self:is_disable())
        if ImGui.ButtonEx(self.label, self.uidata.width, self.uidata.height) then
            self.modifier.click()
        end
        ImGui.EndDisabled()
        ImGui.PopID()
    end
end

local Container = class("Container", PropertyBase)

function Container:_init(config, subproperty, modifier)
    PropertyBase._init(self, config, modifier)
    self.subproperty = subproperty
end

function Container:update()
    for _, pro in ipairs(self.subproperty) do
        if pro.update then
            pro:update()
        end
    end
end

function Container:set_subproperty(subproperty)
    self.subproperty = subproperty
    self:update()
end

function Container:find_property(id)
    for _, p in ipairs(self.subproperty) do
        if p.id == id then
            return p
        end
    end
end

function Container:find_property_by_label(l)
    for _, p in ipairs(self.subproperty) do
        if p.label == l then
            return p
        end
    end
end

function Container:_show_child(c)
    if c:is_visible() then
        ImGui.BeginDisabled(c:is_disable())
        c:show()
        ImGui.EndDisabled()
    end
end

-- 'Group' should call Tree
local Group = class("Group", Container)

function Group:_init(config, subproperty, modifier)
    Container._init(self, config, subproperty, modifier)
    if self.uidata.flags == nil then
        self.uidata.flags = ImGui.TreeNodeFlags { "DefaultOpen" }
    end
end

function Group:show()
    ImGui.BeginDisabled(self:is_disable())
    if ImGui.TreeNodeEx(self.label, self.uidata.flags) then
        for _, c in ipairs(self.subproperty) do
            self:_show_child(c)
            if c.sameline then
                ImGui.SameLine()
            end
        end
        ImGui.TreePop()
    end
    ImGui.EndDisabled()
end

local SameLineContainer = class("SameLineContainer", Container)

function SameLineContainer:_init(config, subproperty)
    Container._init(self, config)
    self.subproperty = subproperty
end

function SameLineContainer:show()
    if self:is_visible() then
        local p = self.subproperty
        for i=1, #p-1 do
            local c = p[i]
            self:_show_child(c)
            ImGui.SameLine()
        end
        self:_show_child(p[#p])
    end
end


return {
    Button          = Button,
    Combo           = Combo,
    Int             = Int,
    Float           = Float,
    Bool            = Bool,
    Color           = Color,
    Text            = Text,
    EditText        = EditText,
    ResourcePath    = ResourcePath,
    TextureResource = TextureResource,
    Group           = Group,
    SameLineContainer = SameLineContainer,
    DirectionalArrow = DirectionalArrow
}