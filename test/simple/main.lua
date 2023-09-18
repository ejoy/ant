package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    feature = {
        "ant.test.simple",
        "ant.animation",
        "ant.render",
        "ant.camera|camera_controller",
        "ant.objcontroller|pickup",
        "ant.sky|procedural_sky",
    },
}
