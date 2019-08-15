local gui_main = import_package "ant.imgui".gui_main
local GuiLogView = import_package "ant.imgui".editor.gui_logview
local GuiSysInfo = import_package "ant.imgui".editor.gui_sysinfo
local GuiSceneHierarchyView = import_package "ant.imgui".editor.gui_scene_hierarchy_view
local GuiPropertyView = import_package "ant.imgui".editor.gui_property_view
local GuiComponentStyle = import_package "ant.imgui".editor.gui_component_style
local GuiComponentStyle = import_package "ant.imgui".editor.gui_component_style
local GuiScriptRunner = import_package "ant.imgui".editor.gui_script_runner
local GuiShaderWatch = import_package "ant.imgui".editor.gui_shader_watch
local gui_mgr = import_package "ant.imgui".gui_mgr
local args = {
    screen_width = 1680,
    screen_height = 960,
}
local main = {}
function main.init()
    local TestGuiBase = require "test_gui_base"
    local GuiEditorMenu = require "gui_editor_menu"
    local GuiScene = require "gui_scene"
   
    gui_mgr.register(GuiEditorMenu.GuiName,GuiEditorMenu.new())

    gui_mgr.register(GuiScene.GuiName,GuiScene.new())
    gui_mgr.register(GuiSysInfo.GuiName,GuiSysInfo.new())
    gui_mgr.register(GuiSceneHierarchyView.GuiName,GuiSceneHierarchyView.new())
    gui_mgr.register(GuiPropertyView.GuiName,GuiPropertyView.new())
    gui_mgr.register(GuiComponentStyle.GuiName,GuiComponentStyle.new())
    local log_view = GuiLogView.new()

    gui_mgr.register(GuiLogView.GuiName,log_view)

    local testgui = TestGuiBase.new(true)
    gui_mgr.register(TestGuiBase.GuiName,testgui)

    gui_mgr.register(GuiScriptRunner.GuiName,GuiScriptRunner.new())
    gui_mgr.register(GuiShaderWatch.GuiName,GuiShaderWatch.new())

end

pm = require "antpm"
log.info_a(pm.get_entry_pkg())



gui_main.run(main,args)