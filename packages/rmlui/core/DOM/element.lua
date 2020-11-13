local event = require "core.event"
local mt = {}local m = {}
mt.__index = m

local style_mt = {}
function style_mt:__index(name)
    return rmlui.ElementGetProperty(self._handle, name)
end
function style_mt:__newindex(name, value)
    if value == nil then
        rmlui.ElementRemoveProperty(self._handle, name)
    elseif type(value) == "string" then
        rmlui.ElementSetProperty(self._handle, name, value)
    else
        rmlui.ElementSetProperty(self._handle, name, tostring(value))
    end
end

local function constructor(document, handle)
    local o = {
        _handle = handle,
        ownerDocument = document,
        style = setmetatable({_handle = handle}, style_mt)
    }
    return setmetatable(o, mt)
end

local pool = {}

function event.OnDeleteDocument(handle)
    pool[handle] = nil
end

return function (document, handle)
    if handle == nil then
        return
    end
    local _pool = pool[document._handle]
    if not _pool then
        _pool = {}
        pool[document._handle] = _pool
    end
    local o = _pool[handle]
    if not o then
        o = constructor(document, handle)
        _pool[handle] = o
    end
    return o
end
