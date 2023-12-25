package.path = "/engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    window_size = "1280x720",
    enable_mouse = true,
    feature = {
        "ant.render|render",
        "ant.test.light",
        "ant.camera|camera_controller",
        "ant.efk",
        "ant.sky|sky",
    }
}
