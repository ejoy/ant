local gui_main = import_package "ant.imgui".gui_main
local gui_mgr = import_package "ant.imgui".gui_mgr
local args = {
    sceen_width = 1024,
    sceen_height = 768,
}
local main = {}
function main.init()
local TestGuiBase = require "test_gui_base"
    -- local GuiSceneMenu = require "gui_scene_menu"
    local GuiScene = require "gui_scene"
    gui_mgr.register(GuiScene.GuiName,GuiScene.new())
    -- gui_mgr.register(GuiSceneMenu.GuiName,GuiSceneMenu.new())
    gui_mgr.register(TestGuiBase.GuiName,TestGuiBase.new())
end

gui_main.run(main,args)