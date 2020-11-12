local event = require "core.event"
local createElement = require "core.DOM.element"

local mt = {}
local m = {}
mt.__index = m

function m:getElementById(id)
    return createElement(self, rmlui.DocumentGetElementById(self._handle, id))
end

local function constructor(handle)
    return setmetatable({_handle = handle}, mt)
end

local pool = {}

function event.OnDeleteDocument(handle)
    pool[handle] = nil
end

return function (handle)
    if handle == nil then
        return
    end
    local o = pool[handle]
    if not o then
        o = constructor(handle)
        pool[handle] = o
    end
    return o
end
