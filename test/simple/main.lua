package.path = "/engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    feature = {
        "ant.render|render",
        "ant.test.simple",
        "ant.animation",
        "ant.camera|camera_controller",
        "ant.objcontroller|pickup",
        "ant.sky|sky",
        "ant.widget"
    },
}
