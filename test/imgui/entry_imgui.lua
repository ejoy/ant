local gui_main = import_package "ant.imgui".gui_main
-- local GuiLogView = import_package "ant.imgui".gui_logview
local GuiSysInfo = import_package "ant.imgui".gui_sysinfo
local gui_mgr = import_package "ant.imgui".gui_mgr
local args = {
    sceen_width = 1024,
    sceen_height = 768,
}
local main = {}
function main.init()
    local TestGuiBase = require "test_gui_base"
    local GuiScene = require "gui_scene"
    gui_mgr.register(GuiScene.GuiName,GuiScene.new())
    gui_mgr.register(GuiSysInfo.GuiName,GuiSysInfo.new())
    gui_mgr.register(TestGuiBase.GuiName,TestGuiBase.new())
    -- gui_mgr.register(GuiLogView.GuiName,GuiLogView.new())
end

gui_main.run(main,args)