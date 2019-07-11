local imgui   = require "imgui_wrap"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local gui_util = {}

function gui_util.get_all_schema()
    local pm = require "antpm"
    local packages = pm.get_pkg_list(true)
    for k,v in ipairs(packages) do
        if v == "ant.ecs" then
            table.remove(packages,k)
            break
        end
    end
    -- log.info_a("all_package:",packages)
    local systems = {"timesystem", "message_system"}
    local inputmgr      = import_package "ant.inputmgr"
    local scene         = import_package "ant.scene".util
    local input_queue = inputmgr.queue()
    local world = scene.start_new_world(input_queue, 600, 400, packages, systems)
    local world_update = scene.loop(world, {
            update = {"timesystem", "message_system"}
        })
    -- world_update()
    -- log.info_a(world._schema.map)
    -- log(world._schema.map)
    return world._schema.map
end

-----------------------------------------------------------------------------
-- example
-- gui_util.notice({msg="123"})
-- gui_util.message({msg="1234",close_cb=function(result) log(result) end})
-----------------------------------------------------------------------------

--arg.msg = * 
--arg.title = "notice"
--arg.show_btn1 = true
--arg.btn1 = "confirm"
function gui_util.notice(arg)
    if arg.show_btn1 == nil then  arg.show_btn1 = true end
    if arg.btn1 == nil then  arg.btn1 = "Confirm" end
    if arg.title == nil then  arg.title = "Notice" end
    assert(arg.msg)
    arg.loop_func = function()
        widget.Text(arg.msg)
        widget.Text(string.format("%60s",""))
        cursor.Separator()
        if arg.show_btn1 then
            windows.PushStyleVar(enum.StyleVar.FramePadding,5,0)
            if widget.Button(arg.btn1) then
                windows.CloseCurrentPopup()
            end
            util.SetItemDefaultFocus()
            windows.PopStyleVar()
        end
    end
    gui_util.popup(arg)
end

--arg.msg = * 
--arg.title = "Message"
--arg.show_btn1 = true
--arg.show_btn2 = true
--arg.close_cb = nil, function close_cb(1 or 2 or 0)
--arg.btn1 = "Confirm"
--arg.btn2 = "Cancel"
function gui_util.message(arg)
    if arg.show_btn1 == nil then  arg.show_btn1 = true end
    if arg.show_btn2 == nil then  arg.show_btn2 = true end
    if arg.btn1 == nil then  arg.btn1 = "Confirm" end
    if arg.btn2 == nil then  arg.btn2 = "Cancel" end
    if arg.title == nil then  arg.title = "Message" end
    assert(arg.msg)
    arg.loop_func = function()
        
        widget.Text(arg.msg)
        widget.Text(string.format("%60s",""))
        cursor.Separator()
        local result = 0
        if arg.show_btn1 then
            if widget.Button(arg.btn1) then
                windows.CloseCurrentPopup()
                arg.result = 1
            end
        end
        if arg.show_btn2 then
            cursor.SameLine()
            if widget.Button(arg.btn2) then
                windows.CloseCurrentPopup()
                arg.result = 2
            end
        end
        
    end
    gui_util.popup(arg)
end


gui_util.popup_idx = 0
gui_util.popup_tbl = {}

--arg.flags
--arg.title
--arg.loop_func
function gui_util.popup(arg)
    local flags = arg.flags or flags.Window.AlwaysAutoResize
    local title = arg.title or "Popup"
    gui_util.popup_idx = gui_util.popup_idx + 1
    local titleid = string.format( "%s###Popup%d", title, gui_util.popup_idx)
    local popup_tbl = gui_util.popup_tbl
    local pf = nil
    local first_time = true
    pf = function()
        windows.PushStyleVar(enum.StyleVar.WindowPadding,16,16)
        if windows.BeginPopupModal(titleid,flags) then
            arg.loop_func()
            windows.EndPopup()
        elseif not first_time then
            --closed
            for i,f in ipairs(popup_tbl) do
                if f == pf then
                    table.remove(popup_tbl,i)
                    break
                end
            end
            if arg.close_cb then
                arg.close_cb(arg.result)
            end

        end
        if first_time then
            windows.OpenPopup(titleid)
        end
        first_time = false
        windows.PopStyleVar()
    end
    table.insert(popup_tbl,pf)
    
end

function gui_util.loop_popup()
    local popup_tbl = gui_util.popup_tbl
    local f = popup_tbl[#popup_tbl]
    if f then
        f()
    end
    -- for i,f in ipairs(popup_tbl) do
    --     f()
    -- end
end

function gui_util.open_current_pkg_path(path,...)
    local fs = require "filesystem"
    local localfs = require "filesystem.local"
    local pm = require "antpm"
    local pkg_path = fs.path(pm.get_entry_pkg().."/"..path)
    local local_path = pkg_path:localpath()
    local f = localfs.open(local_path,...)
    return f
end

local DefaultComponentSettingPath = "editor.com_sytle.default.cfg"
--schema_map to update component list
function gui_util.read_component_setting(schema_map)
    local ComponentSetting = require "editor.component_setting"
    local thread = require "thread"
    local f = gui_util.open_current_pkg_path(DefaultComponentSettingPath,"rb")
    local packed_data = f:read("*all")
    f:close()
    local com_setting_data = thread.unpack(packed_data)
    local com_setting = ComponentSetting.new("")
    com_setting:load_setting(schema_map,com_setting_data)
    return com_setting
end

function gui_util.save_component_setting(com_setting)
    local data = com_setting:get_save_data()
    log.info_a("after:",data)
    local thread = require "thread"
    local packed_data = thread.pack(data)
    -- local after = thread.unpack(packed_data)
    local path = DefaultComponentSettingPath
    local f = gui_util.open_current_pkg_path(path,"wb")
    f:write(packed_data)
    f:close()
    return path
end

return gui_util