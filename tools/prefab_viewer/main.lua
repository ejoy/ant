package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    import = {
        "@ant.tools.prefab_viewer",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
    system = {
        "ant.tools.prefab_viewer|init_system",
    },
    policy = {
        "ant.general|name",
        "ant.scene|scene_object",
        "ant.render|render",
        "ant.render|render_queue",
    }
}
