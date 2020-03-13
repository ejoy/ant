local imgui             = require "imgui_wrap"
local widget            = imgui.widget
local flags             = imgui.flags
local windows           = imgui.windows
local util              = imgui.util
local cursor            = imgui.cursor
local enum              = imgui.enum
local IO                = imgui.IO

local hub = import_package("ant.editor").hub
local Event = require "hub_event"

local pm                = require "antpm"
local gui_input         = require "gui_input"
local gui_mgr         = require "gui_mgr"
local gui_util          = require "editor.gui_util"
local fs                = require "filesystem"


local GuiBase           = require "gui_base"
local GuiInspectorView    = GuiBase.derive("GuiInspectorView")
GuiInspectorView.GuiName  = "GuiInspectorView"

function GuiInspectorView:_init()
    GuiBase._init(self)
    self.title_id = string.format("Inspector###%s",self.GuiName)
    self.default_size = {400,700}
    self.res_inspector = {}
    self:_init_res_inspector()
    self:_init_subcribe()
end


function GuiInspectorView:_init_res_inspector()
    local GLBInspector = require "editor.inspector.glb_inspector"
    local SceneInspector = require "editor.inspector.scene_inspector"
    self:_register_inspector(GLBInspector.new())
    self:_register_inspector(SceneInspector.new())
end

function GuiInspectorView:_register_inspector(inspector_ins)
    local typ = inspector_ins:get_type()
    assert(not self.res_inspector[typ])
    self.res_inspector[typ] = inspector_ins
end

function GuiInspectorView:_init_subcribe()
    hub.subscribe(Event.ETE.InspectRes,self.on_inspect_res,self)
end

function GuiInspectorView:on_inspect_res(pkg_path_strs)
    log.info_a(pkg_path_strs)
    if #pkg_path_strs == 1 then
        local pkg_path_str = pkg_path_strs[1]
        local pkg_path = fs.path(pkg_path_str)
        self:set_inspector_data(pkg_path)
        gui_mgr.set_focus_window(GuiInspectorView.GuiName)
    else
        self:set_inspector_data(pkg_path_strs)
        gui_mgr.set_focus_window(GuiInspectorView.GuiName)
    end
end

function GuiInspectorView:find_inspector(pkg_path)
    if not pkg_path.__name then
        return nil
    end
    local ext = pkg_path:extension():string()
    ext = string.sub(ext,2)
    ext = string.lower(ext)
    return self.res_inspector[ext]
end

function GuiInspectorView:set_inspector_data(res_data)
    local function open_new()
        self.inspector_data = res_data
        self.cur_inspector = self:find_inspector(res_data)
        if self.cur_inspector then
            self.cur_inspector:set_res(res_data)
        end
    end
    local is_closing = self.close_cb
    self.close_cb = open_new
    if not is_closing then
        self:try_close_res()
    end
end
function GuiInspectorView:on_update()
    if self.inspector_data then
        if self.cur_inspector then
            self.cur_inspector:on_update()
        else
            widget.Text("Selection Files")
            if self.inspector_data.__name then
                widget.Text(self.inspector_data:string())
            else
                for k,v in ipairs(self.inspector_data) do
                    widget.Text(v)
                end
            end
        end
    else
        widget.Text("Not Resource")
    end
end

function GuiInspectorView:try_close_res()
    local function close_cb(success)
        if success then
            self.close_cb()
        end
        self.close_cb = nil
    end
    if self.inspector_data and self.cur_inspector then
        self.cur_inspector:try_close_res(close_cb)
    else
        close_cb(true)
    end
end

return GuiInspectorView