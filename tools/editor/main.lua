__ANT_EDITOR__ = true

package.path = "/engine/?.lua"
require "bootstrap"
import_package "ant.imgui".start {
    packagename = "tools.editor",
    w = 1920,
    h = 1080,
    ecs = {
        enable_mouse = true,
        feature = {
            "ant.render|render",
            "tools.editor",
            "ant.animation",
            "ant.daynight",
            "ant.efk",
            "ant.landform",
            "ant.modifier",
            "ant.motion_sampler",
            "ant.objcontroller|pickup",
            "ant.objcontroller|pickup_detect",
            "ant.objcontroller|screen_3dobj",
            "ant.rmlui",
            "ant.sky|sky",
        }
    }
}
