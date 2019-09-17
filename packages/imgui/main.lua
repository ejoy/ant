local editor = {
    imgui = require "imgui_wrap",
    gui_mgr = require "gui_mgr",
    gui_input = require "gui_input",
    gui_packages = require "gui_packages",
    gui_base = require "gui_base",
    gui_main = require "gui_main",
    class = require "common.class",
    controls = {
        list = require "controls.list",
        tree = require "controls.tree",
        combobox = require "controls.combobox",
        scroll_list = require "controls.scroll_list",
        simple_plotline = require "controls.simple_plotline",
    },
    editor = {
        gui_canvas = require "editor.gui_canvas",
        gui_logview = require "editor.gui_log.gui_logview",
        gui_sysinfo = require "editor.gui_sysinfo",
        gui_scene_hierarchy_view = require "editor.gui_scene_hierarchy_view",
        gui_property_view = require "editor.gui_property_view",
        gui_component_style = require "editor.gui_component_style",
        gui_util = require "editor.gui_util",
        gui_script_runner = require "editor.gui_script_runner",
        gui_shader_watch = require "editor.gui_shader_watch",
        gui_system_profiler = require "editor.gui_system_profiler",
        gui_project_view = require "editor.gui_project_view",
    },
}
return editor

