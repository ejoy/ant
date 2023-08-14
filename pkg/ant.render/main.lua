require "render_system.bind_bgfx_math_adapter"	--for bind bgfx api to math adapter

return {
    sampler     = import_package "ant.compile_resource".sampler,
	viewidmgr   = require "viewid_mgr",
	fbmgr       = require "framebuffer_mgr",
    declmgr     = require "vertexdecl_mgr",
}
