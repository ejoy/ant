require "render_system.bind_bgfx_math_adapter"	--for bind bgfx api to math adapter
return {
    sampler     = import_package "ant.compile_resource".sampler,
	fbmgr       = require "framebuffer_mgr",
    layoutmgr   = require "vertexlayout_mgr",
}
