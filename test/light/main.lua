package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    import = {
        "@ant.test.light",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
    feature = {
        "ant.sky|sky",
    },
    system = {
        "ant.test.light|init_system",
    },
    policy = {
        "ant.scene|scene_object",
        "ant.render|render",
        "ant.render|render_queue",
    }
}
