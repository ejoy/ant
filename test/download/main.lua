package.path = "/engine/?.lua"
require "bootstrap"

import_package "ant.window".start {
    feature = {
        "ant.test.download",
        "ant.animation",
        "ant.render|render",
    }
}
