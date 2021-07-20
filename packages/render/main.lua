
return {
	init_bgfx   = function ()
        require "render_system.bind_bgfx_math_adapter"	--for bind bgfx api to math adapter
    end,
	viewidmgr   = require "viewid_mgr",
	fbmgr       = require "framebuffer_mgr",
    declmgr     = require "vertexdecl_mgr",
    sampler     = require "sampler",
}
