package.path = "engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    import = {
        "@ant.render",
    },
    feature = {
        "tools.prefab_viewer",
        "ant.animation",
        "ant.efk",
        "ant.landform",
        "ant.objcontroller|pickup_detect",
        "ant.rmlui",
        "ant.sky|sky",
    },
    policy = {
        "ant.render|render",
        "ant.render|render_queue",
    }
}
