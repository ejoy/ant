package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.test.simple",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
    feature = {
        "ant.sky|procedural_sky"
    },
    system = {
        "ant.test.simple|init_system",
    },
    policy = {
        "ant.scene|scene_object",
        "ant.render|render",
        "ant.render|render_queue",
        "ant.objcontroller|pickup",
    }
}
