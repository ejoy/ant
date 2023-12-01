package.path = "/engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    feature = {
        "ant.render|render",
        "ant.test.efk",
        "ant.camera|camera_controller",
        "ant.efk",
        "ant.sky|sky",
    }
}
