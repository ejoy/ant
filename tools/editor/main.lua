__ANT_EDITOR__ = true

package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.imgui".start {
    packagename = "tools.editor",
    w = 1920,
    h = 1080,
    ecs = {
        enable_mouse = true,
        import = {
            "@tools.editor"
        },
        pipeline = {
            "init",
            "update",
            "exit",
        },
        feature = {
            "ant.animation",
            "ant.daynight",
            "ant.efk",
            "ant.modifier",
            "ant.motion_sampler",
            "ant.rmlui",
            "ant.sky|sky",
        },
        system = {
            "tools.editor|init_system",
            "tools.editor|gizmo_system",
            "tools.editor|input_system",
            "tools.editor|grid_brush_system",
            "tools.editor|gui_system",
            "tools.editor|camera_system",
            "ant.objcontroller|pickup_system",
            -- "ant.camera|default_camera_controller",
        }
    }
}
