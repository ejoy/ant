local imgui     = require "imgui_wrap"
local widget    = imgui.widget
local flags     = imgui.flags
local windows   = imgui.windows
local util      = imgui.util


local gui_mgr = {}

function gui_mgr.init()
    gui_mgr.gui_tbl = {}
    gui_mgr.mainmenu_list = {}
    ----
    local menu_list = {
        {{"Views"},gui_mgr._update_mainmenu_view}
    }
    gui_mgr._register_mainmenu(nil,menu_list)
end


function gui_mgr.update(delta)
    --update main_menu_bar
    --update gui
    imgui.begin_frame(delta)
    gui_mgr._update_mainmenu()
    gui_mgr._update_window(delta)
    imgui.end_frame()
end

function gui_mgr._update_window(delta)
    for ui_name,ui_ins in pairs(gui_mgr.gui_tbl) do
        ui_ins:on_gui(delta)
    end
end

function gui_mgr._update_mainmenu()
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
                fun(target)
            end

        end
    end

    local cur_list = gui_mgr.mainmenu_list

    if widget.BeginMainMenuBar() then
        render_list(cur_list)
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
    --print_a(gui_mgr.mainmenu_list)
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
end

function gui_mgr.get(name)
    assert(type(name)=="string","ui name must be string!")
    return gui_mgr.gui_tbl[name]
end

gui_mgr.init()

return gui_mgr