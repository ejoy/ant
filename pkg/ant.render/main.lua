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

return {
	init_bgfx   = init_bgfx,
	viewidmgr   = require "viewid_mgr",
	fbmgr       = require "framebuffer_mgr",
    declmgr     = require "vertexdecl_mgr",
    sampler     = require "sampler",
    queuemgr    = require "queue_mgr",
}
