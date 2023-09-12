package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.test.material",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
    system = {
        "ant.test.material|init_system",
    },
    policy = {
        "ant.scene|scene_object",
        "ant.render|render",
        "ant.render|render_queue",
    }
}
