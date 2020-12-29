local event = require "core.event"
local createElement = require "core.DOM.element"

local mt = {}
local m = {}
mt.__index = m

function m:getElementById(id)
    return createElement(rmlui.DocumentGetElementById(self._handle, id), self._handle)
end

local function constructor(handle)
    return setmetatable({_handle = handle}, mt)
end

local pool = {}

function event.OnDocumentCreate(document, globals)
    local o = constructor(document)
    globals.document = o
    pool[document] = o
end

function event.OnDocumentDestroy(handle)
    pool[handle] = nil
end

return function (handle)
    if handle == nil then
        return
    end
    return pool[handle]
end
