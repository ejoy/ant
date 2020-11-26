local event = require "core.event"

local attribute_mt = {}

function attribute_mt:__index(k)
    return rmlui.ElementGetAttribute(self._handle, k)
end
function attribute_mt:__newindex(k, v)
    if v == nil then
        rmlui.ElementRemoveAttribute(self._handle, k)
    else
        rmlui.ElementSetAttribute(self._handle, k, v)
    end
end

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

local api = {}
function api:addEventListener(type, listener, useCapture)
    rmlui.ElementAddEventListener(self._handle, type, listener, useCapture)
end

local function constructor(document, handle)
    local createDocument = require "core.DOM.document"
    local o = {
        _handle = handle,
        ownerDocument = createDocument(document),
        style = setmetatable({_handle = handle}, style_mt)
    }
    for k,v in pairs(api) do
        o[k] = v
    end
    return setmetatable(o, attribute_mt)
end

local pool = {}

function event.OnDeleteDocument(handle)
    pool[handle] = nil
end

return function (handle, document)
    if handle == nil then
        return
    end
    if not document then
        document = rmlui.ElementGetOwnerDocument(handle)
    end
    local _pool = pool[document]
    if not _pool then
        _pool = {}
        pool[document] = _pool
    end
    local o = _pool[handle]
    if not o then
        o = constructor(document, handle)
        _pool[handle] = o
    end
    return o
end
