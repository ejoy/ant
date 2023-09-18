package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    feature = {
        "ant.test.atmosphere",
        "ant.camera|camera_controller",
        "ant.render",
        "ant.efk",
        "ant.sky|sky",
    }
}
