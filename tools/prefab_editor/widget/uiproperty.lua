local imgui     = require "imgui"
local assetmgr  = import_package "ant.asset"
local cr        = import_package "ant.compile_resource"
local datalist  = require "datalist"
local uiconfig  = require "widget.config"
local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local vfs       = require "vfs"
local access    = require "vfs.repoaccess"
local global_data = require "common.global_data"
local utils     = require "common.utils"
local rc        = import_package "ant.compile_resource"
local class     = utils.class 

local PropertyBase = class "PropertyBase"

function PropertyBase:_init(config, modifier)
    self.label      = config.label
    self.readonly   = config.readonly
    self.disable    = config.disable
    self.visible    = config.visible or true

    self.modifier = modifier or {}
    self.dim = config.dim or 1
    self.uidata = {speed = config.speed, min = config.min, max = config.max, flags = config.flags}
    -- if self.dim == 1 then
    --     self.uidata = {0, speed = config.speed, min = config.min, max = config.max, flags = config.flags}
    -- elseif self.dim == 2 then
    --     self.uidata = {0, 0, speed = config.speed, min = config.min, max = config.max, flags = config.flags}
    -- elseif self.dim == 3 then
    --     self.uidata = {0, 0, 0, speed = config.speed, min = config.min, max = config.max, flags = config.flags}
    -- elseif self.dim == 4 then
    --     self.uidata = {0, 0, 0, 0, speed = config.speed, min = config.min, max = config.max, flags = config.flags}
    -- end
end

function PropertyBase:set_userdata(userdata)
    self.userdata = userdata
end

function PropertyBase:set_label(label)
    self.label = label
end

function PropertyBase:set_getter(getter)
    self.modifier.getter = getter
end

function PropertyBase:set_setter(setter)
    self.modifier.setter = setter
end

function PropertyBase:is_enable()
    return not self.disable
end

function PropertyBase:set_enable(v)
    self.disable = not v
end


function PropertyBase:is_visible()
    return self.visible
end

function PropertyBase:set_visible(v)
    self.visible = v
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

function PropertyBase:show()
    imgui.widget.PropertyLabel(self.label)
    if self.imgui_func("##" .. self.label, self.uidata) then
        if self.dim == 1 then
            self.modifier.setter(self.uidata[1])
        else
            self.modifier.setter(self.uidata)
        end
    end
end

local Int = class("Int", PropertyBase)

function Int:_init(config, modifier)
    PropertyBase._init(self, config, modifier)
    self.imgui_func = imgui.widget.DragInt
end

local Float = class("Float", PropertyBase)

function Float:_init(config, modifier)
    PropertyBase._init(self, config, modifier)
    self.imgui_func = imgui.widget.DragFloat
end

local Bool = class("Bool", PropertyBase)
function Bool:_init(config, modifier)
    PropertyBase._init(self, config, modifier)
    self.imgui_func = imgui.widget.Checkbox
end

local Color = class("Color", PropertyBase)

function Color:_init(config, modifier)
    PropertyBase._init(self, config, modifier)
    self.imgui_func = imgui.widget.ColorEdit
end

local Combo = class "Combo"

function Combo:_init(config, modifier)
    self.label          = config.label
    self.options        = config.options
    self.current_option = config.options[1]
    self.modifier       = modifier
end

function Combo:set_getter(getter)
    self.modifier.getter = getter
end

function Combo:set_setter(setter)
    self.modifier.setter = setter
end

function Combo:update()
    self.current_option = self.modifier.getter()
end

function Combo:set_options(options)
    self.options = options
    self.current_option = options[1]
end

function Combo:show()
    imgui.widget.PropertyLabel(self.label)
    imgui.util.PushID(tostring(self))
    if imgui.widget.BeginCombo("##"..self.label, {self.current_option, flags = imgui.flags.Combo {}}) then
        for _, option in ipairs(self.options) do
            if imgui.widget.Selectable(option, self.current_option == option) then
                self.current_option = option
                self.modifier.setter(option)
            end
        end
        imgui.widget.EndCombo()
    end
    imgui.util.PopID()
end

local EditText = class("EditText", PropertyBase)

function EditText:_init(config, modifier)
    PropertyBase._init(self, config, modifier)
    self.uidata = {text = ""}
    self.imgui_func = imgui.widget.InputText
end

function EditText:show()
    imgui.widget.PropertyLabel(self.label)
    if self.readonly then
        imgui.widget.Text(tostring(self.uidata.text))
    else
        if self.imgui_func("##" .. self.label, self.uidata) then
            self.modifier.setter(tostring(self.uidata.text))
        end
    end
end

function EditText:update()
    self.uidata.text = self.modifier.getter()
end

local ResourcePath      = class("ResourcePath", EditText)
local utils             = require "common.utils"

function ResourcePath:_init(config, modifier)
    EditText._init(self, config, modifier)
    self.extension = config.extension
end

function ResourcePath:update()
    local path = self.modifier.getter()
    self.path = path
    self.uidata.text = path
end

local uiutils       = require "widget.utils"

local stringify     = import_package "ant.serialize".stringify

function ResourcePath:on_dragdrop()
    
end

function ResourcePath:get_extension()
    return self.extension
end

function ResourcePath:show()
    -- imgui.widget.Text(self.label)
    -- imgui.cursor.SameLine(uiconfig.PropertyIndent)
    imgui.widget.PropertyLabel(self.label)
    if self.imgui_func("##" .. self.label, self.uidata) then
    end
    if imgui.widget.BeginDragDropTarget() then
        local payload = imgui.widget.AcceptDragDropPayload("DragFile")
        if payload then
            local relative_path = lfs.path(payload)--lfs.relative(lfs.path(payload), fs.path "":localpath())
            local extension = tostring(relative_path:extension())
            if extension == self.extension then
                local path_str = tostring(payload)
                self.path = path_str
                self.uidata.text = path_str
                self.modifier.setter(path_str)
                self:on_dragdrop()
            end
        end
        imgui.widget.EndDragDropTarget()
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
        self.metadata = serialize.parse(self.path, cr.read_file(self.path))
        if self.metadata.path[1] ~= '/' then
            self.metadata.path = r[1] .. "|images/" .. fs.path(self.metadata.path):filename():string()
        end
    else
        self.metadata = utils.readtable(self.path)
    end
    self.runtimedata = assetmgr.resource(self.path)
    if not self.uidata2 then
        self.uidata2 = {text = ""}
    end
    self.uidata2.text = self.metadata.path
    local s = self.runtimedata.sampler
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
    self.uidata2.text = self.metadata.path
    if string.sub(path, -4) ~= ".dds" then
        local t = assetmgr.resource(path, { compile = true })
        self.runtimedata._data.handle = t.handle
    end
end

function TextureResource:show()
    ResourcePath.show(self)
    if not self.runtimedata then return end
    --if not self.runtimedata._data.handle then return end
    if imgui.table.Begin("##TextureTable" .. self.label, 2, imgui.flags.Table {}) then
        imgui.table.SetupColumn("ImagePreview", imgui.flags.TableColumn {'WidthFixed'}, 64.0)
        imgui.table.SetupColumn("ImagePath", imgui.flags.TableColumn {'NoHide', 'WidthStretch'}, 1.0)
        imgui.table.NextColumn()
        if self.runtimedata._data.handle then
            imgui.widget.Image(self.runtimedata._data.handle, uiconfig.PropertyImageSize, uiconfig.PropertyImageSize)
        end
        imgui.table.NextColumn()
        imgui.cursor.PushItemWidth(-1)
        if imgui.widget.InputText("##" .. self.metadata.path .. self.label, self.uidata2) then
        end
        imgui.cursor.PopItemWidth()
        if imgui.widget.BeginDragDropTarget() then
            local payload = imgui.widget.AcceptDragDropPayload("DragFile")
            if payload then
                local path = fs.path(payload);
                if path:equal_extension ".png" or path:equal_extension ".dds" then
                    self:set_file(tostring(path))
                    assetmgr.unload(self.path)
                end
            end
            imgui.widget.EndDragDropTarget()
        end

        if not self.readonly then
            imgui.util.PushID("Save" .. self.label)
            if imgui.widget.Button("Save") then
                if not self.path:find("|", 1, true) then
                    utils.write_file(self.path, stringify(self.metadata))
                end
            end
            imgui.util.PopID()
            imgui.cursor.SameLine()
        end
        
        imgui.util.PushID("Save As" .. self.label)
        if imgui.widget.Button("Save As") then
            local path = uiutils.get_saveas_path("Texture", "texture")
            if path then
                --path = tostring(lfs.relative(lfs.path(path), fs.path "":localpath()))
                utils.write_file(path, stringify(self.metadata))
            end
        end
        imgui.util.PopID()
        imgui.cursor.SameLine()
        
        if imgui.widget.Button("Select...") then
            local glb_filename = uiutils.get_open_file_path("Textures", "glb")
            if glb_filename then
                glb_path = "/" .. access.virtualpath(global_data.repo, fs.path(glb_filename))
                rc.compile(glb_path)
                image_path = rc.compile(glb_path .. "|images")
                imgui.windows.OpenPopup("select_image")
            end
        end
        imgui.cursor.SameLine()
        if image_path then
            if imgui.windows.BeginPopup("select_image") then
                for path in image_path:list_directory() do
                    if path:equal_extension ".png" or path:equal_extension ".dds" then
                        local filename = path:filename():string()
                        if imgui.widget.Selectable(filename, false) then
                            self:set_file(glb_path .. "|images/" .. filename)
                            image_path = nil
                        end
                    end
                end
                imgui.windows.EndPopup()
            end
        end
        imgui.table.End()
    end
end


local Button = class "Button"
local button_id = 0
function Button:_init(config, modifier)
    button_id = button_id + 1
    self.label      = config.label
    self.modifier   = modifier or {}
end

function Button:set_click(click)
    self.modifier.click = click
end

function Button:show()
    imgui.util.PushID("ui_button_id" .. button_id)
    if imgui.widget.Button(self.label) then
        self.modifier.click()
    end
    imgui.util.PopID()
end

local Group = class "Group"

function Group:_init(config, subproperty)
    self.label        = config.label
    self.subproperty = subproperty
end

function Group:update()
    for _, pro in ipairs(self.subproperty) do
        if pro.update then
            pro:update()
        end
    end
end

function Group:set_subproperty(subproperty)
    self.subproperty = subproperty
    self:update()
end

function Group:find_property(id)
    for _, p in ipairs(self.subproperty) do
        if p.id == id then
            return p
        end
    end
end

function Group:find_property_by_label(l)
    for _, p in ipairs(self.subproperty) do
        if p.label == l then
            return p
        end
    end
end

function Group:show()
    if imgui.widget.TreeNode(self.label, imgui.flags.TreeNode { "DefaultOpen" }) then
        for _, pro in ipairs(self.subproperty) do
            imgui.windows.BeginDisabled(pro.disable)
            if pro.visible then
                pro:show()
            end
            imgui.windows.EndDisabled()
        end
        imgui.widget.TreePop()
    end
end

return {
    Combo           = Combo,
    Int             = Int,
    Float           = Float,
    Bool            = Bool,
    Color           = Color,
    EditText        = EditText,
    ResourcePath    = ResourcePath,
    TextureResource = TextureResource,
    Group           = Group,
    Button          = Button
}