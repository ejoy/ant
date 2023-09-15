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
        "ant.animation",
        "ant.objcontroller|pickup",
        "ant.sky|procedural_sky",
    },
    system = {
        "ant.test.simple|init_system",
    },
    policy = {
        "ant.render|render",
        "ant.render|render_queue",
    }
}
