package.path = "/engine/?.lua"
require "bootstrap"
import_package "ant.window".start {
    enable_mouse = true,
    feature = {
        "tools.prefab_viewer",
        "ant.anim_ctrl",
        "ant.animation",
        "ant.efk",
        "ant.landform",
        "ant.objcontroller|pickup_detect",
        "ant.rmlui",
        "ant.sky|sky",
    }
}
