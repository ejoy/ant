package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    import = {
        "@ant.test.simple",
    },
    pipeline = {
        "init",
        "update",
        "exit",
    },
    system = {
        "ant.test.simple|init_system",
    },
    interface = {
        "ant.objcontroller|obj_motion",
        "ant.animation|animation",
        "ant.effekseer|effekseer_playback",
    },
    policy_v2 = {
        "ant.general|name",
        "ant.scene|scene_object",
        "ant.render|render",
        "ant.render|render_queue",
        "ant.objcontroller|pickup",
    }
}
