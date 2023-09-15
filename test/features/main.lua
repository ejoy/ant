package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    import = {
        "@ant.test.features",
    },
    feature = {
        "ant.animation",
        "ant.camera|camera_controller",
        "ant.camera|camera_recorder",
        "ant.daynight",
        "ant.motion_sampler",
        "ant.objcontroller|screen_3dobj",
        "ant.sky|sky",
        "ant.sky|procedural_sky",
        "ant.splitviews",
        "ant.terrain|canvas",
        "ant.terrain|water",
    },
    system = {
        "ant.test.features|init_loader_system",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
}
