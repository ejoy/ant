local native = require "window.native"
local window = require "window"
local bgfx = require "bgfx"
local platform = require "platform"
local renderpkg = import_package "ant.render"
local hw = renderpkg.hardware_interface
local viewidmgr = renderpkg.viewidmgr

local assetutil = import_package "ant.asset".util
local imgui   = import_package "ant.imgui".imgui
-- local imgui = require "bgfx.imgui"
local widget = imgui.widget
local flags = imgui.flags
local windows = imgui.windows
local util = imgui.util
local enum = imgui.enum
local font = imgui.font
local Font = platform.font

local callback = {
    mouse_move = imgui.mouse_move,
    mouse_wheel = imgui.mouse_wheel,
    mouse_click = imgui.mouse_click,
    keyboard = imgui.key_state,
    char = imgui.input_char,
    error = log
}

local attribs = {}

function callback.init(nwh, context, width, height)
    hw.init {
        nwh = nwh,
        context = context,
    --  renderer = "DIRECT3D9",
    --  renderer = "OPENGL",
        width = width,
        height = height,
    --  reset = "v",
    }

    local ocornut_imgui = assetutil.shader_loader {
        vs = "/pkg/ant.testimgui/shader/vs_ocornut_imgui",
        fs = "/pkg/ant.testimgui/shader/fs_ocornut_imgui",
    }
    local imgui_image = assetutil.shader_loader {
        vs = "/pkg/ant.testimgui/shader/vs_imgui_image",
        fs = "/pkg/ant.testimgui/shader/fs_imgui_image",
    }

    imgui.create(nwh);
    imgui.viewid(viewidmgr.generate "ui");
    imgui.program(
        ocornut_imgui.prog,
        imgui_image.prog,
        ocornut_imgui.uniforms.s_tex.handle,
        imgui_image.uniforms.u_imageLodEnabled.handle
    )
    imgui.resize(width, height)
    imgui.keymap(native.keymap)

    bgfx.set_view_rect(0, 0, 0, width, height)
    bgfx.set_view_clear(0, "CD", 0x303030ff, 1, 0)

    bgfx.set_view_rect(1, 200, 200, width-100, height-100)
    bgfx.set_view_clear(1, "CD", 0xffff00ff, 1, 0)

 -- bgfx.set_debug "ST"
    font.Create {
        platform.OS == "Windows"
        and { Font "黑体" ,    18, "\x20\x00\xFF\xFF\x00"}
        or  { Font "华文细黑" , 18, "\x20\x00\xFF\xFF\x00"},
    }
end

function callback.size(width,height,type)
    log("callback.size",width,height,type)
    imgui.resize(width,height)
    hw.reset(nil, width, height)
    bgfx.set_view_rect(0, 0, 0, width, height)
end


local editbox = {
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

local checkbox = {}

local combobox = { "B" }

local lines = { 1,2,3,2,1 }

local test_window = {
    id = "Test",
    open = true,
    flags = flags.Window { "MenuBar" }, -- "NoClosed"
}

local function run_window(wnd)
    if not wnd.open then
        return
    end
    local touch, open = windows.Begin(wnd.id, wnd.flags)
    if touch then
        wnd:update()
        wnd.open = open
    windows.End()
    end
end

local lists = { "Alice", "Bob" }

local tab_noclosed = flags.TabBar { "NoClosed" }

function test_window:update()
    self:menu()
    if windows.BeginTabBar "tab_bar" then
        if windows.BeginTabItem ("Tab1",tab_noclosed) then
            self:tab_update()
            windows.EndTabItem()
        end
        if windows.BeginTabItem ("Tab2",tab_noclosed) then
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
        windows.EndTabBar()
    end
end

function test_window:menu()
    if widget.BeginMenuBar() then
        widget.MenuItem("M1")
        widget.MenuItem("M2")
        widget.EndMenuBar()
    end
end

local TreeOpen = {true}
function test_window:tab_update()
    if widget.Button "Print imgui.IO" then
        log.info_a(imgui.IO)
    end
    if widget.Button "Test" then
        log("test2")
    end
    widget.SmallButton "Small"
    widget.Checkbox("TreeOpen",TreeOpen)
    if widget.Checkbox("Checkbox", checkbox) then
        log("Click Checkbox", checkbox[1])
    end
    if widget.InputText("Edit", editbox) then
        log(editbox.text)
    end
    widget.InputFloat("InputFloat", editfloat)
    widget.Text("Hello World", 1,0,0)
    if widget.BeginCombo( "Combo", combobox ) then
        widget.Selectable("A", combobox)
        widget.Selectable("B", combobox)
        widget.Selectable("C", combobox)
        widget.EndCombo()
    end
    if widget.TreeNode "TreeNodeA" then
        widget.SetNextItemOpen(TreeOpen[1])
        TreeOpen[1] =  widget.TreeNode "TreeNodeAA"
        if TreeOpen[1] then
            if widget.TreeNode("TreeNodeAA1",flags.TreeNode.DefaultOpen) then
                if widget.TreeNode "TreeNodeAA11" then
                    widget.TreePop()
                end
                if widget.TreeNode "TreeNodeAA12" then
                    widget.TreePop()
                end
                widget.TreePop()
            end
            if widget.TreeNode "TreeNodeAA2" then
                widget.TreePop()
            end
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
end

local function update_ui()
    windows.SetNextWindowSizeConstraints(300, 300, 500, 500)
    run_window(test_window)
end

local ioo
local os = require "os"
local last = os.clock()
function callback.update(delta)
    local now = os.clock()
    delta = now - last
    last = now
    -- log(delta)
    -- log("-----------------------------")
    imgui.begin_frame( delta + 0.0001)

    update_ui()
    imgui.end_frame()

    bgfx.touch(0)
    bgfx.touch(1)

--  bgfx.dbg_text_clear()
--  bgfx.dbg_text_log(0, 1, 0xf, "Color can be changed with ANSI \x1b[9;me\x1b[10;ms\x1b[11;mc\x1b[12;ma\x1b[13;mp\x1b[14;me\x1b[0m code too.");
    
    bgfx.frame()
    local thread = require "thread"
    thread.sleep(0.015)

end

function callback.exit()
    log("Exit")
    imgui.destroy()
    hw.shutdown()
end

window.register(callback)

native.create(1024, 768, "Hello")
native.mainloop()
