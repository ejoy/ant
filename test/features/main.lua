package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    feature = {
        "ant.test.features",
        "ant.animation",
        "ant.camera|camera_controller",
        "ant.camera|camera_recorder",
        "ant.daynight",
        "ant.motion_sampler",
        "ant.objcontroller|screen_3dobj",
        "ant.render",
        "ant.sky|sky",
        "ant.sky|procedural_sky",
        "ant.splitviews",
        "ant.terrain|canvas",
        "ant.terrain|water",
    }
}
