package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    import = {
        "@ant.render",
    },
    feature = {
        "ant.test.efk",
        "ant.camera|camera_controller",
        "ant.efk",
        "ant.sky|sky",
    },
    policy = {
        "ant.render|render",
        "ant.render|render_queue",
    }
}
