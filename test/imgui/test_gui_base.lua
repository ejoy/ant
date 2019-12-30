local imgui   = import_package "ant.imgui".imgui
local gui_util   = import_package "ant.imgui".editor.gui_util
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local cursor = imgui.cursor
local enum = imgui.enum
local mult_widget = import_package "ant.imgui".controls.mult_widget
local bgfx = require "bgfx"

local gui_input = import_package "ant.imgui".gui_input

local GuiBase = import_package "ant.imgui".gui_base

local TestGuiBase = GuiBase.derive("TestGuiBase")


TestGuiBase.GuiName = "TestGuiBase"
function TestGuiBase:_init(default_collapsed)
    GuiBase._init(self)
    self.title = "Imgui Demo"
    self.id = "Test"
    self.title_id = self.title.."###"..self.id
    self.win_flags = flags.Window { "MenuBar" }
    self._is_opened = true
    local fs = require "filesystem"
    self.texrefpath1 = "/pkg/ant.resources/depiction/textures/test/1x1_normal.texture"
    -- local f = assert(fs.open(texrefpath1, "rb"))
    -- local imgdata1 = f:read "a"
    -- f:close()
    -- self.texhandle1 = bgfx.create_texture(imgdata1, "")

    -- local texrefpath2 = fs.path("/pkg/ant.resources.binary/textures/PVPScene/BH-Scene-Tent-d.tga")
    -- local f2 = assert(fs.open(texrefpath2, "rb"))
    -- local imgdata2 = f2:read "a"
    -- f2:close()
    -- self.texhandle2 = bgfx.create_texture(imgdata2, "")

    self.default_collapsed = default_collapsed
end

function TestGuiBase:before_update()
    windows.SetNextWindowCollapsed(self.default_collapsed,"A")
end

local tab_noclosed = flags.TabBar { "NoClosed" }
function TestGuiBase:on_update()
    windows.PushStyleVar( enum.StyleVar.WindowPadding,0,0)
    if widget.BeginMenuBar() then
        if widget.MenuItem("Print IO") then
            -- local scene_control = require "scene_control"
            -- scene_control.test_new_world()
            log("hello")
            log.info_a(imgui.IO)
        end
        
        widget.MenuItem("M2")
        widget.EndMenuBar()
    end
    if windows.BeginTabBar "tab_bar" then
        if windows.BeginTabItem ("Tab1",tab_noclosed) then
            self:tab1_update()
            windows.EndTabItem()
        end
        if windows.BeginTabItem ("Tab2",tab_noclosed) then
            self:tab2_update() 
            if widget.Button "Save Ini" then
                log(util.SaveIniSettings())
            end
            if windows.BeginPopupModal "Popup window" then
                widget.Text "Pop up"
                windows.EndPopup()
            end
            if widget.Button "Popup" then
                windows.OpenPopup "Popup window"
            end
            windows.EndTabItem()
        end
        if windows.BeginTabItem ("Tab3",tab_noclosed) then
            self:tab3_update()
            windows.EndTabItem()
        end
        if windows.BeginTabItem ("Tab_NormalScroll",tab_noclosed) then
            self:tab4_update()
            windows.EndTabItem()
        end
        if windows.BeginTabItem ("Tab_ScrollList",tab_noclosed) then
            self:tab_scroll_litem()
            windows.EndTabItem()
        end
        if windows.BeginTabItem ("Tab_Temp",tab_noclosed) then
            self:tab_temp()
            windows.EndTabItem()
        end
        windows.EndTabBar()
    end
    windows.PopStyleVar()
end

local editfloat = {
    0,
    step = 0.1,
    step_fast = 10,
}
local checkbox = {}
local combobox = { "B" }
local lines = { 1000,2,3,2,1 }
local lists = { "Alice", "Bob" }
local editbox = {
    text = "asd",
    flags = flags.InputText { "CallbackCharFilter", "CallbackHistory", "CallbackCompletion" },
}
function editbox:filter(c)
    if c == 65 then
        -- filter 'A'
        return
    end
    return c
end

local t = 0
function editbox:up()
    t = t - 1
    return tostring(t)
end

function editbox:down()
    t = t + 1
    return tostring(t)
end

function editbox:tab(pos)
    t = t + 1
    return tostring(t)
end

local editfloat = {
    0,
    step = 0.1,
    step_fast = 10,
}

function TestGuiBase:create_textbox()
    local editbox = {
        text = "nil",
        flags = flags.InputText { "CallbackCharFilter", "CallbackHistory", "CallbackCompletion" },
        count = 0, 
    }
    function editbox:filter(c)
        if c == 65 then
            -- filter 'A'
            return
        end
        return c
    end
    local t = 0 
    function editbox:up()
        t = t - 1
        return tostring(t)
    end

    function editbox:down()
        t = t + 1
        return tostring(t)
    end
 
    function editbox:tab(pos)
        t = t + 1
        return tostring(t)
    end
    return editbox
end
local editbox_dynamic = nil
local editbox_editing = false
local editbox_testfloat = {
    test = "--"
}
local mult_float = {0.1,0.2,0.3,0.4}
local mult_int = {1,2,3,4}
local mult_vector = {{0.1,0.2,0.3,0.4},{0.1,0.2,0.3,0.5},{0.2,0.3,0.3,0.5}}
local mult_boolean = {false,true,false}
function TestGuiBase:tab1_update()
    do --test mult_widget
        if widget.CollapsingHeader("Test Mult Number Drag",flags.TreeNode.DefaultOpen) then
            widget.DragFloat("Mult Float##test_show",mult_float)

            mult_widget.DragFloat("DragMultFloat##test_mult",mult_float,{})
            widget.DragInt("Mult Int##test_show",mult_int)
            mult_widget.DragInt("DragMultInt##test_mult",mult_int,{})
            for i = 1,#mult_vector do
                widget.DragFloat("Vector"..i.."##test_show",mult_vector[i])
            end
            mult_widget.DragVector("DragMultVector##test_mult",mult_vector,{})
            for i = 1,#mult_boolean do
                local _
                _,mult_boolean[i] = widget.Checkbox("bool"..i.."##test_show",mult_boolean[i])
                cursor.SameLine()
            end
            mult_widget.Checkbox("Mult Boolean##test_show",mult_boolean,{})
        end
    end
    windows.PushStyleVar(enum.StyleVar.FrameBorderSize,2.0)
    windows.PushStyleVar(enum.StyleVar.WindowBorderSize,2.0)

    widget.Button("DropTest")

    if util.IsItemHovered() and gui_input.get_dropfiles() then
        log.info_a("testgui",gui_input.get_dropfiles() )
    end

    local dds_path = "/pkg/ant.resources/depiction/PVPScene/siegeweapon_d.texture"
    widget.Image(dds_path,200,200,{border_col={1.0,0.0,1.0,1.0},tint_col={0.0,1.0,1.0,0.5}})
    local dds_path2 = "/pkg/ant.resources/depiction/PVPScene/siegeweapon_n.texture"
    widget.Image(dds_path2,600,600,{border_col={1.0,1.0,1.0,1.0},tint_col={1.0,1.0,1.0,1}})
    if  widget.ImageButton(self.texrefpath1,50,50,
            {uv0={0.5,0.5},
            uv1={1,1},
            bg_col={0.5,0.5,0.5,0.5},
            frame_padding=10}) then
        log("clicked")
    end
    windows.PopStyleVar(2)
    windows.PushStyleColor(enum.StyleCol.Button,1,1,1,1)
    if widget.Button "Test" then
        log("test1")
    end
    windows.PopStyleColor()

    if widget.Button "Test" then
        log("test2")
    end
    widget.SmallButton "Small"
    if widget.Checkbox("Checkbox", checkbox) then
        log("Click Checkbox", checkbox[1])
    end
    if widget.InputText("Set Title", editbox) then
        log(editbox.text)
    end
    if widget.Button("Set Window Title") then
        local gui_mgr = import_package "ant.imgui".gui_mgr
        local window = require "window"
        window.set_title(gui_mgr.win_handle,tostring(editbox.text))
    end
    if (not editbox_dynamic) or (editbox_dynamic.count > 2000) then
        editbox_dynamic = self:create_textbox()
    end
    -- editbox_dynamic.count = editbox_dynamic.count + 1
    -- if widget.InputText("EditDynamic", editbox_dynamic) then
    --     log(editbox_dynamic.text)
    -- end
    -- widget.InputFloat("InputFloat", editfloat)
    local is_editing = widget.InputFloat("InputFloat", editfloat)
    log("editor:",is_editing)
    if is_editing then
        log(editfloat[1])
    end
    log("float:",util.IsItemFocused(),util.IsItemActivated(),util.IsItemEdited(),util.IsItemDeactivated())
    if widget.InputText("editbox_dynamic", editbox_dynamic) then
        log(editbox_dynamic.text)
    end
    -- log("text",util.IsItemFocused(),util.IsItemActivated(),util.IsItemEdited(),util.IsItemDeactivated())


    

    cursor.SetNextItemWidth(-1)
    widget.LabelText("##asd","asdad\nasdasds")
    widget.BulletText("asdad\nasdasds")

    widget.Text("Hello World", 1,0,0)
    
    if widget.BeginCombo( "Combo", combobox ) then
        widget.Selectable("A", combobox)
        widget.Selectable("B", combobox)
        widget.Selectable("C", combobox)
        widget.EndCombo()
    end
    if widget.TreeNode "TreeNodeA" then
        if widget.TreeNode "TreeNodeAA" then
            widget.TreePop()
        end
        widget.TreePop()
    end
    if widget.TreeNode "TreeNodeB" then
        widget.TreePop()
    end
    if widget.TreeNode "TreeNodeC" then
        widget.TreePop()
    end

    widget.PlotLines("lines", lines)
    widget.PlotHistogram("histogram", lines)

    if widget.ListBox("##list",lists) then
        log(lists.current)
    end
    widget.ProgressBar(0.3,"asd")
end


--main menu
function TestGuiBase:get_mainmenu()
    local parent_path_1 = {"TestMainMenu1"}
    local parent_path_2 = {"TestMainMenu2"}
    local parent_path_3 = {"TestMainMenu2","TestMainMenu22"}
    return {{parent_path_1,self._main_menu_test1},
            {parent_path_2,self._main_menu_test2},
            {parent_path_3,self._main_menu_test3}}
end

function TestGuiBase:_main_menu_test1()
    if widget.MenuItem("t1","CTRL+C") then
        log("menu t1 click")
    end
    cursor.Separator()
    if widget.MenuItem("wantcapturemouse","graytext") then
        log("menu t2 click")
    end
    -- cursor.Separator()

end
function TestGuiBase:_main_menu_test2()
    if widget.BeginMenu("t2-1") then
        if widget.MenuItem("t2-11") then
            log("menu t2-1 click")
        end
        widget.EndMenu()
    end
end
function TestGuiBase:_main_menu_test3()
    if widget.MenuItem("t2-2") then
        log("menu 2-2 click")
    end
end
--main menu
local tab2_selected = false
local tab2_vector = {1.0,1.0,1.0,1.0}
function TestGuiBase:tab2_update()
    --display a TreeNode with arrow on righthand
    local change = widget.Selectable("TreeNode",tab2_selected,nil,nil,flags.Selectable.SpanAllColumns)
    if change then tab2_selected = not tab2_selected end
    cursor.SameLine()
    if change then
        widget.SetNextItemOpen(tab2_selected)
    end
    if widget.TreeNode("##Treenode") then
        widget.Text("child")
        widget.TreePop()
    end
    local change = widget.DragFloat("Test",tab2_vector)
    if change then
        log.info_a(tab2_vector)
    end
    --

end

local Tree = import_package "ant.imgui".controls.tree
local List = import_package "ant.imgui".controls.list
local ComboBox = import_package "ant.imgui".controls.combobox
local SimplePlotline = import_package "ant.imgui".controls.simple_plotline
local offset_2 = nil
local g_change = false
local frame_count = 0
function TestGuiBase:tab3_update()
    frame_count = frame_count + 1
    if not self.tree then
        local root = Tree.Node.new( "Root",nil,{"this is root's data"},true)
        local node1 = Tree.Node.new( "Node1",root,{"this is Node1's data"},true)
        local node1_1 = Tree.Node.new( "node1_1",node1,nil,true)
        local node2 = Tree.Node.new( "Node2",root,nil,true)
        local node2_1 = Tree.Node.new( "node2_1",node2,nil,true)
        local node2_2 = Tree.Node.new( "node2_2",node2,nil,false)
        local node2_2_1 = Tree.Node.new( "node2_2_1",node2_2,nil,false,true)
        
        local tree = Tree.new()
        tree:set_root(root)
        local function cb(node,change)
            log("Tree cb",node.title,node.data,change)
        end
        tree:set_node_change_cb(cb)
        self.tree = tree
    end
    self.tree:update()

    if not self.list then
        local list = List.new("List Example")
        local datalist = {
            "ItemA",
            "ItemB",
            "ItemC",
            "ItemD",
            "ItemE",
            "ItemF",
            height = 4,
        }
        local function cb(index)
            log("List:selected_change_cb",index)
        end 
        list:set_selected_change_cb(cb)
        list:set_data(datalist,nil)
        self.list = list
    end
    self.list:update()

    if not self.simple_plotline then
        self.simple_plotline  = SimplePlotline.new("SimplePlotline",100)
    end
    if frame_count%50== 0 then
        self.simple_plotline:add_value(math.sin(frame_count/200))
    end
    self.simple_plotline:update()
    
    if not self.combo then
        local combo = ComboBox.new("ComboBox Example")
        local datalist = {
            "ItemA0",
            "ItemB0",
            "ItemC0",
            "ItemD0",
            "ItemE0",
            "ItemF0",
            "ItemA1",
            "ItemB1",
            "ItemC1",
            "ItemD1",
            "ItemE1",
            "ItemF1",
            "ItemA2",
            "ItemB2",
            "ItemC2",
            "ItemD2",
            "ItemE2",
            "ItemF2",
        }
        combo:set_data(datalist,2)
        local function cb(index)
            log("Combo:selected_change_cb",index)
        end 
        combo:set_selected_change_cb(cb)
        self.combo = combo
    end
    self.combo:update()

    --make columns with *different id* has the same offset
    --test columns
    widget.Text("Test Columns With Border")
    local print_index = widget.Button("Print Column Index")
    local change = false
    local new_offset = nil
    cursor.Columns(3,"test_columns_with_border1",true)
    if g_change then
        cursor.SetColumnOffset(2,offset_2)
    end
    cursor.Separator()
    for i = 1,12 do
        if print_index then
            log("ColumnsIndex:",cursor.GetColumnIndex())
        end
        widget.Text("Item"..i)
        cursor.NextColumn()
    end
    if not change then
        new_offset = cursor.GetColumnOffset(2)
        change = offset_2 and (new_offset ~= offset_2)
        offset_2 = new_offset
    end
    cursor.Columns(1)
    
    widget.Text("Test Columns With Border2")
    cursor.Columns(3,"test_columns_with_border",true)
    if g_change then
        cursor.SetColumnOffset(2,offset_2)
    end
    cursor.Separator()
    for i = 1,12 do
        widget.Text("Item"..i)
        cursor.NextColumn()
    end
    if not change then
        new_offset = cursor.GetColumnOffset(2)
        change = (new_offset ~= offset_2)
        offset_2 = new_offset
    end
    g_change = change
    cursor.Columns(1)
    cursor.Separator()
    cursor.Columns(3,"test_columns_without_border",false)
    cursor.Separator()
    for i = 1,12 do
        widget.Text("Item"..i)
        cursor.NextColumn()
    end
    cursor.Columns(1)
end

local scroll_line = {
    100,
    min = 10,
    max = 10000,
}
function TestGuiBase:tab4_update()
    local flag = flags.Window.HorizontalScrollbar
    widget.DragInt("Line",scroll_line)
    local click = false
    click = widget.Button("Test")
    windows.BeginChild("Child",0,0,false,flag)
    if click then
        log.info_a("windows.GetContentRegionAvail()",windows.GetContentRegionAvail())
        log.info_a("GetScrollY",windows.GetScrollY())
        log.info_a("GetCursorPos",cursor.GetCursorPos())
    end
    for i = 1,scroll_line[1] do
        widget.Text("Line"..i)
    end
    cursor.SetCursorPos(nil,20*300)
    windows.EndChild()
end


local ScrollList = import_package "ant.imgui".controls.scroll_list

local line = 10
local scroll_list = nil
local cache = {}
local hidecache = {}
local scroll_func = function(index)
    if not cache[index] then
        cache[index] = 1
    end
    if hidecache[index] then
        return
    end
    if widget.Button("ExpandBtn###"..index) then
        cache[index] = cache[index] + 1
    end
    if widget.Button("Hide"..index) then
        hidecache[index] = true
        print(index,hidecache[index])
    end
    for i =1,cache[index] do
        widget.Text("Line"..index)
    end
    cursor.Separator()
end
function TestGuiBase:tab_scroll_litem()
    if not scroll_list then
        scroll_list = ScrollList:new()
        scroll_list:set_data_func(scroll_func)
        scroll_list:add_item_num(line)
    end
    if widget.Button("Twice of "..line) then
        line = line * 2 
        scroll_list:add_item_num(line - scroll_list:get_size())
    end
    cursor.SameLine()
    if widget.Button("Remove All") then
        scroll_list:remove_all()
    end
    local flag = flags.Window.HorizontalScrollbar
    windows.BeginChild("Child",0,0,false,flag)
    scroll_list:update()
    windows.EndChild()
end

function TestGuiBase:tab_temp()
    widget.DragFloat("Vector1##test_show",mult_vector[1])
    mult_widget.DragVector("DragMultVector##test_mult",mult_vector,{})
    -- widget.LabelText("LabelOP1231231231231231231231231231231231231231231232","Value1231241231312312312312313123123123123123")
end

return TestGuiBase