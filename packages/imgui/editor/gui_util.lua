local imgui   = require "imgui_wrap"
local gui_input   = require "gui_input"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local gui_util = {}

function gui_util.get_pkg_list()
    local fs = require "filesystem"
    local res = {}
    for pkg in fs.path('/pkg'):list_directory() do
        res[#res+1] = pkg:filename():string()
    end
    return res
end


function gui_util.get_all_components()
    local packages = gui_util.get_pkg_list()
    for k = #packages,1,-1 do
        local v = packages[k]
        if v == "ant.ecs" or v == "project" then
            table.remove(packages,k)
        end
    end
    local ecs         = import_package "ant.ecs"
    local world = ecs.get_schema({}, packages)
    -- world_update()
    -- log.info_a(world._schema.map)
    -- log(world._schema.map)
    -- log.info_a(world)
    return world._class.component
end

local all_scheme = nil
function gui_util.get_all_schema(force)
    if not force and all_scheme then
        return all_scheme
    end
    local packages = gui_util.get_pkg_list()
    for k = #packages,1,-1 do
        local v = packages[k]
        if v == "ant.ecs" or v == "project" then
            table.remove(packages,k)
        end
    end
    -- log.info_a("all_package:",packages)
    -- local systems = {"timesystem", "message_system"}
    -- local inputmgr      = import_package "ant.inputmgr"
    -- local scene         = import_package "ant.scene".util
    -- local input_queue = inputmgr.queue()
    local ecs         = import_package "ant.ecs"
    local world = ecs.get_schema({}, packages)
        -- })
    -- world_update()

    all_scheme =  {
        policies = world._class.policy,
        transforms = world._class.transform,
        components = world._class.component,
    }
    return all_scheme
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
--arg.id = arg.id or arg.msg
function gui_util.notice(arg)
    arg.id = arg.id or arg.msg
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
    gui_util._popup(arg)
end

--arg.msg = * 
--arg.title = "Message"
--arg.show_btn1 = true
--arg.show_btn2 = true
--arg.close_cb = nil, function close_cb(1 or 2 or 0)
--arg.btn1 = "Confirm"
--arg.btn2 = "Cancel"
--arg.id = arg.id or arg.msg
function gui_util.message(arg)
    arg.id = arg.id or arg.msg
    if arg.show_btn1 == nil then  arg.show_btn1 = true end
    if arg.show_btn2 == nil then  arg.show_btn2 = true end
    if arg.btn1 == nil then  arg.btn1 = "Yes" end
    if arg.btn2 == nil then  arg.btn2 = "No" end
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
    gui_util._popup(arg)
end

function gui_util.popup(update_func,title,flags)
    local arg = {
        loop_func = update_func,
        title = title,
        flags = flags,
        id = title or tostring(loop_func),
    }
    gui_util._popup(arg)
end


gui_util.popup_idx = 0
gui_util.popup_list = {}
gui_util.popup_tbl = {}
gui_util.last_popup_id = nil

--arg.flags
--arg.title
--arg.loop_func
function gui_util._popup(arg)
    local flags = arg.flags or flags.Window.AlwaysAutoResize
    local title = arg.title or "Popup"
    gui_util.popup_idx = gui_util.popup_idx + 1
    local my_id = gui_util.popup_idx
    local titleid = string.format( "%s###Popup%d", title, my_id)
    local popup_list = gui_util.popup_list
    local popup_tbl = gui_util.popup_tbl
    if popup_tbl[arg.id] then
        log.trace("repeat message,ignoded")
        return
    end
    local pf = nil
    
    pf = function()
        local first_time = (my_id ~= gui_util.last_popup_id)
        gui_util.last_popup_id = my_id
        if first_time then
            windows.OpenPopup(titleid)
            first_time = false
        end
        windows.PushStyleVar(enum.StyleVar.WindowPadding,16,16)
        if windows.BeginPopupModal(titleid,flags) then
            arg.loop_func()
            windows.EndPopup()
        elseif not first_time then
            --closed
            for i,f in ipairs(popup_list) do
                if f == pf then
                    table.remove(popup_list,i)
                    popup_tbl[arg.id] = nil
                    break
                end
            end
            if arg.close_cb then
                arg.close_cb(arg.result)
            end
        end
        
        windows.PopStyleVar()
    end
    table.insert(popup_list,pf)
    popup_tbl[arg.id] = true
end

function gui_util.loop_popup()
    local popup_list = gui_util.popup_list
    local f = popup_list[#popup_list]
    if f then
        f()
    end
    -- for i,f in ipairs(popup_list) do
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
    return f,local_path:string()
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

---cb(type,path)
--return update_func
function gui_util.watch_current_package_file(file_path,cb)
    local fs = require "filesystem"
    local localfs = require "filesystem.local"
    local current_path = localfs.current_path()
    local pm = require "antpm"
    local pkg_path = fs.path(pm.get_entry_pkg().."/"..file_path)
    local local_path = pkg_path:localpath()
    local dir_path = local_path:parent_path():string()
    local local_path_str = local_path:string()
    local full_target_path = (current_path.."/"..local_path_str):string()
    local fw = require 'filewatch'
    log.info(dir_path)
    local watch = assert(fw.add("./"..dir_path))
    local update = function()
        local typ, path = fw.select()
        if typ then
            log.info("watch_current_package_file",typ,path)
            local path_sep = string.gsub(path,"\\","/")
            -- log.trace_a(typ,full_target_path,path_sep,path_sep == full_target_path)
            if path_sep == full_target_path then
                cb(typ)
            end
        end
    end
    return update
end

function gui_util.watch_shader_src(folder_path,cb)
    folder_path = folder_path or "/pkg/ant.resources/shaders"
    local fs = require "filesystem"
    local localfs = require "filesystem.local"
    local current_path = localfs.current_path()
    local pkg_path = fs.path(folder_path)
    local local_path = pkg_path:localpath()
    local local_path_str = local_path:string()
    local full_target_path = (current_path.."/"..local_path_str):string()
    local fw = require 'filewatch'
    log.info(local_path_str)
    local watch = assert(fw.add("./"..local_path_str))
    local update = function()
        local typ, path = fw.select()

        if typ then
            log.info("watch_shader_src",typ,path)
        end
    end
    return update
end

function gui_util.pkg_path_to_local(pkg_path,is_full)
    local fs = require "filesystem"
    if type(pkg_path) == "string" then pkg_path = fs.path(pkg_path) end
    local function dir_to_local(pkg_path,is_full)
        local localfs = require "filesystem.local"
        
        local local_path = pkg_path:localpath()
        local local_path_str = local_path:string()
        if is_full then
            local current_path = localfs.current_path()
            local_path_str = (current_path.."/"..local_path_str):string()
        end
        return local_path_str
    end
    if fs.is_directory(pkg_path) then
        return dir_to_local(pkg_path,is_full)
    else
        local file_name = pkg_path:filename():string()
        local parent_path = dir_to_local(pkg_path:parent_path(),is_full)
        return parent_path.."/"..file_name
    end
end

function gui_util.load_local_file(local_path_str)
    local localfs = require "filesystem.local"
    local env = {}
    local r = loadfile(local_path_str,"t",env)
    if r then
        r()
        return env
    end
end

function gui_util.remount_package(lfs_path)
    local fs = require "filesystem"
    local pm = require "antpm"
    local name = pm.load_package(lfs_path)
    local vfs = require "vfs"
    vfs.unmount("pkg/"..name)
    vfs.add_mount("pkg/"..name,lfs_path)
    pm.unregister_package(fs.path("pkg/"..name))
    pm.register_package(fs.path("pkg/"..name))
end

return gui_util