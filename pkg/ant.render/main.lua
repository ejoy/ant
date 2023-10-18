import_package "ant.math"

return {
    sampler     = import_package "ant.render.core".sampler,
	fbmgr       = require "framebuffer_mgr",
    layoutmgr   = require "vertexlayout_mgr",
}
