local function init_bgfx()
    local ltask = require "ltask"
    local bgfx = require "bgfx"
    local ServiceBgfxMain = ltask.queryservice "ant.render|bgfx_main"
    for _, name in ipairs(ltask.call(ServiceBgfxMain, "CALL")) do
        bgfx[name] = function (...)
            return ltask.call(ServiceBgfxMain, name, ...)
        end
    end
    for _, name in ipairs(ltask.call(ServiceBgfxMain, "SEND")) do
        bgfx[name] = function (...)
            ltask.send(ServiceBgfxMain, name, ...)
        end
    end
    require "render_system.bind_bgfx_math_adapter"	--for bind bgfx api to math adapter
end

local viewidmgr = require "viewid_mgr"
local bgfx = require "bgfx"
local function update_bgfx_viewid_name()
	for n, viewid in pairs(viewidmgr.all_bindings()) do
		bgfx.set_view_name(viewid, n)
	end
end

function viewidmgr.update_view()
    bgfx.set_view_order(viewidmgr.remapping())
    update_bgfx_viewid_name()
end

do
    local g = viewidmgr.generate
	viewidmgr.generate = function (...)
		g(...)
        viewidmgr.update_view()
	end
end


return {
	init_bgfx   = init_bgfx,
	viewidmgr   = viewidmgr,
	fbmgr       = require "framebuffer_mgr",
    declmgr     = require "vertexdecl_mgr",
    sampler     = require "sampler",
}
