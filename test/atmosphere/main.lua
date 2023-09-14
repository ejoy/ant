package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.test.atmosphere",
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
        "ant.test.atmosphere|init_system",
    },
    policy = {
        "ant.scene|scene_object",
        "ant.render|render",
        "ant.render|render_queue",
    }
}
