package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    import = {
        "@ant.test.light",
    },
    feature = {
        "ant.camera|camera_controller",
        "ant.efk",
        "ant.sky|sky",
    },
    system = {
        "ant.test.light|init_system",
    },
    policy = {
        "ant.render|render",
        "ant.render|render_queue",
    }
}
