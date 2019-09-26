local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util
local gui_util  = require "editor.gui_util"
local thread    = require "thread"
local TimeStack = require "common.time_stack"
local gui_input = require "gui_input"
local dbgutil = import_package "ant.editor".debugutil


local gui_mgr = {}
local test = false

local DefaultImguiSetting = "editor.default.setting"
local UserImguiSetting = "editor.user.setting"
local SettingIni = "SettingIni"
local SettingGuiOpen = "SettingGuiOpen"
local CreateDefaultSetting = function()
    return {
        SettingGuiOpen = {},
    }
end

function gui_mgr.init()
    gui_mgr.gui_tbl = {}
    gui_mgr.mainmenu_list = {}
    gui_mgr.setting_tbl = CreateDefaultSetting()
    gui_mgr.setting_status = {
        try_count = 0,
        can_save = nil, -- setting loaded successfully OR user confirm
        max_try_count = 1,
    }
    gui_mgr.time_stack = TimeStack.new()
    gui_mgr.update_list = {}
    gui_mgr.focus_window = nil
    -- local menu_list = {
    --     {{"Views"},gui_mgr._update_mainmenu_view},
    -- }
    -- gui_mgr._register_mainmenu(nil,menu_list)
end

function gui_mgr.after_init()
    -- gui_mgr.load_ini()
    gui_mgr.load_setting()
end

function gui_mgr.update(delta)
    --update main_menu_bar
    --update gui
    local time_stack = gui_mgr.time_stack
    time_stack:Push("editor")
    gui_mgr.check_can_save()
    local setting_can_save = gui_mgr.setting_status.can_save
    imgui.begin_frame(delta)
    --dropfiles
    -- local dropfiles = gui_input.get_dropfiles()

    -- if dropfiles then
    --     log.info("BeginDragDropSource")
    --     if widget.BeginDragDropSource(flags.DragDrop.SourceExtern) then
    --         widget.SetDragDropPayload("DROPFILES","files")
    --         widget.EndDragDropSource()
    --     end
    -- end
    gui_mgr._update_mainmenu(delta)
    imgui.showDockSpace()
    time_stack:Pop("editor")

    if setting_can_save ~= nil then 
        gui_mgr._update_window(delta)
    end
    time_stack:Push("update_list")
    gui_mgr._update_list(delta)
    time_stack:Pop("update_list")


    time_stack:Push("editor")
    gui_util.loop_popup()

    gui_input.set_dropfiles(nil)
    imgui.end_frame()
    if setting_can_save then
        gui_mgr.check_and_save_setting()
    end
    time_stack:Pop("editor")
end

function gui_mgr.process_next_frame_funcs()

end

function gui_mgr.reset_time_count()
    gui_mgr.time_stack:clear()
end

function gui_mgr._update_window(delta)
    local focus_window = gui_mgr.focus_window
    local time_stack = gui_mgr.time_stack
    for ui_name,ui_ins in pairs(gui_mgr.gui_tbl) do
        if ui_ins.on_gui then
            time_stack:Push(ui_name)
            if focus_window and focus_window[ui_ins.GuiName] then
                windows.SetNextWindowFocus()
            end
            ui_ins:on_gui(delta)
            time_stack:Pop(ui_name)
        end
    end
    gui_mgr.focus_window = nil
end

function gui_mgr._update_list(delta)
    local update_list = gui_mgr.update_list
    for _,func in ipairs(update_list) do
        dbgutil.try(func,delta)
    end
end

function gui_mgr._update_mainmenu(delta)
    local function render_list(lst)
        for _,item in ipairs(lst) do
            if item.type == "node" then
                if widget.BeginMenu(item.name) then
                    render_list(item.children)
                    widget.EndMenu()
                end
            else -- fun type
                local target = item.target
                local fun = item.fun
                --todo pcall
                fun(target,delta)
            end

        end
    end

    local cur_list = gui_mgr.mainmenu_list

    if widget.BeginMainMenuBar() then
        render_list(cur_list)
        if widget.BeginMenu( "Views") then
            gui_mgr._update_mainmenu_view()
            widget.EndMenu()
        end
        widget.EndMainMenuBar()
    end
end

function gui_mgr._register_mainmenu(gui_ins,cfg)
    local function indexof(t,v)
        for i,item in ipairs(t) do
            if item.name == v then
                return i
            end
        end
    end
    --get_mainmenu and merge
    local cur_list = gui_mgr.mainmenu_list
    --[[
        proto of mainmenu_list
        item_node = { node = menu_name,children = item_list,type = "node" }
        item_fun = { target=gui_ins, fun=fun,type = "fun"}
        item_list = { [item_node or item_fun ]* }
        mainmenu_list is item_list
    ]]--
    for _,cfg_item in ipairs(cfg) do
        local cur_list = gui_mgr.mainmenu_list
        local paths,fun = cfg_item[1],cfg_item[2]
        for _,node_name in ipairs(paths) do
            local index = indexof(cur_list,node_name)
            if index then
                cur_list = cur_list[index].children
            else
                local newt = {name = node_name,children = {}, type = "node"}
                table.insert(cur_list,newt)
                cur_list = newt.children
            end
        end
        table.insert(cur_list,{target=gui_ins,fun=fun,type="fun"})
    end
    --log.info_a(gui_mgr.mainmenu_list)
end

function gui_mgr._update_mainmenu_view()
    for ui_name,ui_ins in pairs(gui_mgr.gui_tbl) do
        local is_opened =  ui_ins:is_opened()
        local change,status =  widget.MenuItem(ui_name,nil,is_opened)
        if change then
            if status then
                ui_ins:on_open_click()
            else
                ui_ins:on_close_click()
            end
        end
    end
end

function gui_mgr.register(name,gui_ins)
    assert(type(name)=="string","ui name must be string!")
    assert(gui_mgr.gui_tbl[name]==nil,"ui name registered:"..name)
    gui_mgr.gui_tbl[name] = gui_ins
    local cfg = gui_ins:get_mainmenu()
    if cfg then
        gui_mgr._register_mainmenu(gui_ins,cfg)
    end
    if gui_ins.load_setting_from_memory then
        local setting = gui_mgr.setting_tbl[name]
        if setting then
            dbgutil.try( gui_ins.load_setting_from_memory,gui_ins,setting)
        end
        local setting_open = gui_mgr.setting_tbl[SettingGuiOpen][name]
        if setting_open~= nil then
            if (not gui_ins:is_opened()) ~= (not setting_open) then
                if setting_open then
                    gui_ins:on_open_click()
                else
                    gui_ins:on_close_click()
                end
            end
        end
    end
end

function gui_mgr.get(name)
    assert(type(name)=="string","ui name must be string!")
    return gui_mgr.gui_tbl[name]
end

function gui_mgr.register_update(func,target)
    assert(func)
    if target then
        local f = function(...)
            return func(target,...)
        end
        table.insert(gui_mgr.update_list,f)
    else
        table.insert(gui_mgr.update_list,func)
    end
end

function gui_mgr.set_focus_window(name)
    assert(type(name)=="string","ui name must be string!")
    local ins = gui_mgr.get(name)
    if not ins then
        log.info("Try to open unregistered window:",name)
        return 
    end
    if not ins:is_opened() then
        ins:on_open_click()
    end
    gui_mgr.focus_window = gui_mgr.focus_window or {}
    gui_mgr.focus_window[name] = true
end 

---------------gui_setting-------------------------------
function gui_mgr.load_setting()
    local path = UserImguiSetting
    local setting_file = gui_util.open_current_pkg_path(path,"rb")
    if not setting_file then
        path = DefaultImguiSetting
        setting_file = gui_util.open_current_pkg_path(path,"rb")
    end
    if setting_file then
        local packed_data = setting_file:read('*all')
        setting_file:close()
        local tbl = thread.unpack(packed_data) or CreateDefaultSetting()
        tbl[SettingGuiOpen] = tbl[SettingGuiOpen] or {}
        gui_mgr._load_setting_to_gui(tbl)
        gui_mgr.setting_status.can_save = true
        log.trace("Load Imgui setting:",path)
    else
        gui_mgr.setting_tbl = CreateDefaultSetting()
        log.trace("Can't find Imgui setting:",path)
    end

end

function gui_mgr._load_setting_to_gui(tbl)
    print("_load_setting_to_gui")
    gui_mgr.setting_tbl = tbl
    if tbl[SettingIni] then
        util.LoadIniSettings(tbl[SettingIni])
    end
    for ui_name,ui_ins in pairs(gui_mgr.gui_tbl) do
        local gui_cfg = tbl[ui_name]
        if gui_cfg and ui_ins.load_setting_from_memory then
            dbgutil.try( ui_ins.load_setting_from_memory,ui_ins,gui_cfg)
        end
        local setting_open = tbl[SettingGuiOpen][ui_name]
        if setting_open ~= nil then
            if (not ui_ins:is_opened()) ~= (not setting_open) then
                if setting_open then
                    ui_ins:on_open_click()
                else
                    ui_ins:on_close_click()
                end
            end
        end
    end
end

function gui_mgr.check_can_save()
    local setting_status = gui_mgr.setting_status
    if setting_status.can_save == nil then
        if setting_status.try_count >= setting_status.max_try_count then
            setting_status.can_save = false
            local arg = {
                msg = "Fail to load gui setting,auto save layout is disabled."
            }
            gui_util.notice(arg)
        else
            setting_status.try_count = setting_status.try_count + 1
            gui_mgr.load_setting()
        end
    end
end

function gui_mgr.check_and_save_setting()
    gui_mgr.setting_tbl = gui_mgr.setting_tbl or {}
    local setting_tbl = gui_mgr.setting_tbl
    local need_save = false
    if imgui.IO.WantSaveIniSettings then
        need_save = true
        local cfg_data = util.SaveIniSettings(true)
        setting_tbl[SettingIni] = cfg_data
    end
    for ui_name,ui_ins in pairs(gui_mgr.gui_tbl) do
        if ui_ins:is_setting_dirty() then
            need_save = true
            local ok
            log.trace_a("Save setting:",ui_name)
            ok,setting_tbl[ui_name] =  dbgutil.try( ui_ins.save_setting_to_memory,ui_ins,true)
        end
    end
    setting_tbl[SettingGuiOpen] =  setting_tbl[SettingGuiOpen] or {}
    local gui_opens = setting_tbl[SettingGuiOpen]
    for ui_name,ui_ins in pairs(gui_mgr.gui_tbl) do
        if ui_ins:is_opened() ~= gui_opens[ui_name] then
            gui_opens[ui_name] = ui_ins:is_opened()
            need_save = true
        end
    end
    if need_save then
        -- log.trace("Setting changed,save to path:",UserImguiSetting)
        local file,file_path = gui_util.open_current_pkg_path(UserImguiSetting,"wb")
        if file then
            local data = thread.pack(setting_tbl)
            file:write(data)
            file:close()
            if gui_mgr.last_time_save_failed then
                log.trace("Save successfully!")
                gui_mgr.last_time_save_failed = false
            end
        else
            log.error("Can't Open file:",file_path)
            gui_mgr.last_time_save_failed = true
        end
    end
end

function gui_mgr.save_setting_to(path)
    path = path or DefaultImguiSetting
    local file = gui_util.open_current_pkg_path(path,"wb")
    local data = thread.pack(gui_mgr.setting_tbl)
    file:write(data)
    file:close()
    local str = string.format("Save to successfully\nPath:%s",path)
    gui_util.notice({msg =str})
end

---------------gui_setting-------------------------------


gui_mgr.init()

return gui_mgr