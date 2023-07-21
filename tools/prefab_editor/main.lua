package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.imgui".start {
    packagename = "tools.prefab_editor",
    w = 1920,
    h = 1080,
    ecs = {
        enable_mouse = true,
        import = {
            "@tools.prefab_editor"
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        system = {
            "tools.prefab_editor|init_system",
            "tools.prefab_editor|gizmo_system",
            "tools.prefab_editor|input_system",
            "tools.prefab_editor|grid_brush_system",
            "tools.prefab_editor|gui_system",
            "tools.prefab_editor|camera_system",
            "ant.objcontroller|pickup_system",
            -- "ant.camera|default_camera_controller",
        }
    }
}
