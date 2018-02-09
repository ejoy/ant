local bgfx = require "bgfx"

local hw_caps = {}

local caps = nil

function hw_caps.get()
    return assert(caps)
end

function hw_caps.init()
    assert(caps == nil)
    caps = bgfx.get_caps()
end

return hw_caps