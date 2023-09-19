require "bind_adapter"	--for bind bgfx api to math adapter
return {
    sampler     = import_package "ant.render.core".sampler,
	fbmgr       = require "framebuffer_mgr",
    layoutmgr   = require "vertexlayout_mgr",
}
