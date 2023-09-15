package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.render",
    },
    feature = {
        "ant.test.simple",
        "ant.animation",
        "ant.camera|camera_controller",
        "ant.objcontroller|pickup",
        "ant.sky|procedural_sky",
    },
    policy = {
        "ant.render|render",
        "ant.render|render_queue",
    }
}
