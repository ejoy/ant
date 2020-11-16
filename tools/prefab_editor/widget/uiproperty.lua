local imgui     = require "imgui"
local assetmgr  = import_package "ant.asset"
local uiconfig  = require "widget.config"
local fs        = require "filesystem"
local lfs       = require "filesystem.local"
local utils     = require "common.utils"
local class     = utils.class 

local PropertyBase = class("PropertyBase")

function PropertyBase:_init(config, modifier)
    self.label = config.label
    self.modifier = modifier or {}
    self.dim = config.dim or 1
    if self.dim == 1 then
        self.uidata = {0, speed = config.speed, min = config.min, max = config.max}
    elseif self.dim == 2 then
        self.uidata = {0, 0, speed = config.speed, min = config.min, max = config.max}
    elseif self.dim == 3 then
        self.uidata = {0, 0, 0, speed = config.speed, min = config.min, max = config.max}
    elseif self.dim == 4 then
        self.uidata = {0, 0, 0, 0, speed = config.speed, min = config.min, max = config.max}
    end
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
    imgui.widget.Text(self.label)
    imgui.cursor.SameLine(uiconfig.PropertyIndent)
    if self.imgui_func("##" .. self.label, self.uidata) then
        if self.dim == 1 then
            self.modifier.setter(self.uidata[1])
        elseif self.dim == 2 then
            self.modifier.setter(self.uidata[1], self.uidata[2])
        elseif self.dim == 3 then
            self.modifier.setter(self.uidata[1], self.uidata[2], self.uidata[3])
        elseif self.dim == 4 then
            self.modifier.setter(self.uidata[1], self.uidata[2], self.uidata[3], self.uidata[4])
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

local Color = class("Color", PropertyBase)

function Color:_init(config, modifier)
    PropertyBase._init(self, config, modifier)
    self.imgui_func = imgui.widget.ColorEdit
end

local EditText = class("EditText", PropertyBase)

function EditText:_init(config, modifier)
    PropertyBase._init(self, config, modifier)
    self.readonly = config.readonly
    self.uidata = {text = ""}
    self.imgui_func = imgui.widget.InputText
end

function EditText:show()
    imgui.widget.Text(self.label)
    imgui.cursor.SameLine(uiconfig.PropertyIndent)
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
function ResourcePath:update()
    local path = self.modifier.getter()
    self.path = path
    self.uidata.text = path
    local fp = fs.path(path)
    if fp:equal_extension(".material") or fp:equal_extension(".texture") then
        self.metadata = utils.readtable(path)
    end
    if fp:equal_extension(".texture") then
        self.runtimedata = assetmgr.resource(path)
        if not self.uidata2 then
            self.uidata2 = {text = ""}
        end
        self.uidata2.text = self.metadata.path
    end
end

local rhwi          = import_package 'ant.render'.hwi
local stringify     = import_package "ant.serialize".stringify
local filedialog    = require 'filedialog'
local filter_type   = {"POINT", "LINEAR", "ANISOTROPIC"}
local address_type  = {"WRAP", "MIRROR", "CLAMP", "BORDER"}

function ResourcePath:show()
    imgui.widget.Text(self.label)
    imgui.cursor.SameLine(uiconfig.PropertyIndent)
    if self.imgui_func("##" .. self.label, self.uidata) then
    end
    
    local function on_dragdrop(level)
        if imgui.widget.BeginDragDropTarget() then
            local payload = imgui.widget.AcceptDragDropPayload("DragFile")
            if payload then
                local relative_path = lfs.relative(lfs.path(payload), fs.path "":localpath())
                local extension = tostring(relative_path:extension())
                local path_str = tostring(relative_path)
                
                if level == 0 then
                    self.metadata = utils.readtable(path_str)
                    if extension == ".texture" then
                        self.runtimedata = assetmgr.resource(path_str)
                        local s = self.runtimedata.sampler
                    else
                        
                    end
                    self.path = path_str
                    self.uidata.text = path_str
                    self.modifier.setter(path_str)
                elseif level == 1 and (extension == ".png" or extension == ".dds") then
                    local t = assetmgr.resource(path_str, { compile = true })
                    self.runtimedata._data.handle = t.handle
                    self.metadata.path = path_str
                    self.uidata2.text = self.metadata.path
                end
            end
            imgui.widget.EndDragDropTarget()
        end
    end

    on_dragdrop(0)

    if self.runtimedata and self.runtimedata._data then
        -- texture detail
        local texture_handle = self.runtimedata._data.handle
        if texture_handle then
            imgui.cursor.Indent()
            imgui.cursor.Columns(2, self.label, false)
            imgui.cursor.SetColumnOffset(2, uiconfig.PropertyIndent)
            imgui.widget.Image(texture_handle, uiconfig.PropertyImageSize, uiconfig.PropertyImageSize)
            imgui.cursor.SameLine(uiconfig.PropertyImageSize * 2)
            imgui.cursor.NextColumn()
            imgui.widget.Text("image")
            imgui.cursor.SameLine()
            imgui.cursor.PushItemWidth(-1)
            if imgui.widget.InputText("##" .. self.metadata.path .. self.label, self.uidata2) then
            end
            imgui.cursor.PopItemWidth()
            on_dragdrop(1)

            local sampler = self.metadata.sampler
            local function show_filter(ft)
                imgui.widget.Text(ft)
                imgui.cursor.SameLine()
                imgui.cursor.SetNextItemWidth(uiconfig.ComboWidth)
                imgui.util.PushID(ft .. self.label)
                if imgui.widget.BeginCombo("##"..ft, {sampler[ft], flags = imgui.flags.Combo { "NoArrowButton" }}) then
                    for i, type in ipairs(filter_type) do
                        if imgui.widget.Selectable(type, sampler[ft] == type) then
                            sampler[ft] = type
                        end
                    end
                    imgui.widget.EndCombo()
                end
                imgui.util.PopID()
            end
            show_filter("MAG")
            imgui.cursor.SameLine()
            show_filter("MIN")
            imgui.cursor.SameLine()
            show_filter("MIP")

            local function show_uv(uv)
                imgui.widget.Text(uv)
                imgui.cursor.SameLine()
                imgui.cursor.SetNextItemWidth(uiconfig.ComboWidth)
                imgui.util.PushID(uv .. self.label)
                if imgui.widget.BeginCombo("##"..uv, {sampler[uv], flags = imgui.flags.Combo { "NoArrowButton" }}) then
                    for i, type in ipairs(address_type) do
                        if imgui.widget.Selectable(type, sampler[uv] == type) then
                            sampler[uv] = type
                        end
                    end
                    imgui.widget.EndCombo()
                end
                imgui.util.PopID()
            end
            show_uv("U")
            imgui.cursor.SameLine()
            show_uv("V")

            imgui.cursor.SameLine()
            imgui.util.PushID("Save" .. self.label)
            if imgui.widget.Button("Save") then
                local old = self.metadata.path
                self.metadata.path = tostring(lfs.relative(lfs.path(self.metadata.path), lfs.path(self.path):remove_filename()))
                utils.write_file(self.path, stringify(self.metadata))
                self.metadata.path = old
            end
            imgui.util.PopID()
            imgui.cursor.SameLine()
            imgui.util.PushID("Save As" .. self.label)
            if imgui.widget.Button("Save As") then
                local dialog_info = {
                    Owner = rhwi.native_window(),
                    Title = "Save As..",
                    FileTypes = {"Texture", "*.texture" }
                }
                local ok, path = filedialog.save(dialog_info)
                if ok then
                    path = string.gsub(path, "\\", "/") .. ".texture"
                    local pos = string.find(path, "%.texture")
                    if #path > pos + 7 then
                        path = string.sub(path, 1, pos + 7)
                    end
                    local old = self.metadata.path
                    path = tostring(lfs.relative(lfs.path(path), fs.path "":localpath()))
                    self.metadata.path = tostring(lfs.relative(lfs.path(self.metadata.path), lfs.path(path):remove_filename()))
                    utils.write_file(path, stringify(self.metadata))
                    self.metadata.path = old
                end
            end
            imgui.util.PopID()
            imgui.cursor.Unindent()
            imgui.cursor.Columns(1)
        end
    end
end

function ResourcePath:get_path()
    return self.path
end

function ResourcePath:get_metadata()
    return self.metadata
end

local Combo = class("Combo")

function Combo:_init(config, modifier)
    self.label          = config.label
    self.options        = config.options
    self.current_option = config.options[1]
    self.modifier       = modifier
end

function Combo:update()
    self.current_option = self.modifier.getter()
end

function Combo:show()
    imgui.widget.Text(self.label)
    imgui.cursor.SameLine(uiconfig.PropertyIndent)
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

local Button = class("Button")
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

local Group = class("Group")

function Group:_init(config, subproperty)
    self.label        = config.label
    self.subproperty = subproperty
end

function Group:update()
    for _, pro in ipairs(self.subproperty) do
        pro:update() 
    end
end

function Group:set_subproperty(subproperty)
    self.subproperty = subproperty
    self:update()
end

function Group:show()
    if imgui.widget.TreeNode(self.label, imgui.flags.TreeNode { "DefaultOpen" }) then
        for _, pro in ipairs(self.subproperty) do
            pro:show() 
        end
        imgui.widget.TreePop()
    end
end

return {
    Combo           = Combo,
    Int             = Int,
    Float           = Float,
    Color           = Color,
    EditText        = EditText,
    ResourcePath    = ResourcePath,
    Group           = Group,
    Button          = Button
}