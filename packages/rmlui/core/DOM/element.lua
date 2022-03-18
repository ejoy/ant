local rmlui = require "rmlui"
local event = require "core.event"

local constructor

local attribute_mt = {}
function attribute_mt:__index(name)
    return rmlui.ElementGetAttribute(self._handle, name)
end
function attribute_mt:__newindex(name, v)
    if v == nil then
        rmlui.ElementRemoveAttribute(self._handle, name)
    else
        rmlui.ElementSetAttribute(self._handle, name, v)
    end
end

local style_mt = {}
function style_mt:__index(name)
    return rmlui.ElementGetProperty(self._handle, name)
end
function style_mt:__newindex(name, value)
    if value == nil then
        rmlui.ElementSetProperty(self._handle, name)
    elseif type(value) == "string" then
        rmlui.ElementSetProperty(self._handle, name, value)
    else
        rmlui.ElementSetProperty(self._handle, name, tostring(value))
    end
end

local property_init = {}
local property_getter = {}
local property_setter = {}

function property_init:addEventListener()
    local handle = self._handle
    return function (type, listener, useCapture)
        rmlui.ElementAddEventListener(handle, type, listener, useCapture)
    end
end

function property_init:ownerDocument()
    local createDocument = require "core.DOM.document"
    return createDocument(self._document)
end

function property_init:parentNode()
    local parent = rmlui.ElementGetParent(self._handle)
    if parent then
        return constructor(self._document, parent)
    end
end

function property_init:childNodes()
    local n = rmlui.ElementGetChildren(self._handle)
    local children = {}
    for i = 1, n do
        local child = assert(rmlui.ElementGetChildren(self._handle, i-1))
        children[i] = constructor(self._document, child)
    end
    return children
end

function property_init:appendChild()
    local handle = self._handle
    return function (child)
        child._owner = nil
        rmlui.ElementAppendChild(handle, child._handle)
    end
end

function property_init:scrollInsets()
    local handle = self._handle
    return function (l, t, r, b)
        rmlui.ElementSetScrollInsets(handle, l, t, r, b)
    end
end

function property_init:getAttribute()
    local handle = self._handle
    return function (name)
        return rmlui.ElementGetAttribute(handle, name)
    end
end

function property_init:setAttribute()
    local handle = self._handle
    return function (name, value)
        rmlui.ElementGetAttribute(handle, name, value)
    end
end

function property_init:style()
    return setmetatable({_handle = self._handle}, style_mt)
end

function property_init:attributes()
    return setmetatable({_handle = self._handle}, attribute_mt)
end

for name, init in pairs(property_init) do
    property_getter[name] = function (self)
        local v = init(self)
        rawset(self, name, v)
        return v
    end
end

function property_getter:clientLeft()
    local x,_,_,_ = rmlui.ElementGetBounds(self._handle)
    return x
end

function property_getter:clientTop()
    local _,y,_,_ = rmlui.ElementGetBounds(self._handle)
    return y
end

function property_getter:clientWidth()
    local _,_,w,_ = rmlui.ElementGetBounds(self._handle)
    return w
end

function property_getter:clientHeight()
    local _,_,_,h = rmlui.ElementGetBounds(self._handle)
    return h
end

function property_getter:id()
    return rmlui.ElementGetAttribute(self._handle, "id") or ""
end
function property_setter:id(v)
    rmlui.ElementSetAttribute(self._handle, "id", v)
end

function property_getter:className()
    return rmlui.ElementGetAttribute(self._handle, "class") or ""
end
function property_setter:className(v)
    rmlui.ElementSetAttribute(self._handle, "class", v)
end

function property_getter:innerHTML()
    return rmlui.ElementGetInnerHTML(self._handle)
end
function property_setter:innerHTML(v)
    rmlui.ElementSetInnerHTML(self._handle, v)
end

function property_getter:scrollLeft()
    return rmlui.ElementGetScrollLeft(self._handle)
end
function property_setter:scrollLeft(v)
    return rmlui.ElementSetScrollLeft(self._handle, v)
end

function property_getter:scrollTop()
    return rmlui.ElementGetScrollTop(self._handle)
end
function property_setter:scrollTop(v)
    return rmlui.ElementSetScrollTop(self._handle, v)
end

local property_mt = {}
function property_mt:__index(name)
    local getter = property_getter[name]
    if getter then
        return getter(self)
    end
end

function property_mt:__newindex(name, value)
    local setter = property_setter[name]
    if setter then
        return setter(self, value)
    end
    if property_getter[name] then
        error("element property `" .. name .. "` readonly.")
    end
    rawset(self, name, value)
end

function constructor(document, handle, owner)
    return setmetatable({
        _handle = handle,
        _document = document,
        _owner = owner,
    }, property_mt)
end

local pool = {}

function event.OnDocumentDestroy(handle)
    if not pool[handle] then
        return
    end
    for h, e in pairs(pool[handle]) do
        if e._owner then
            rmlui.ElementDelete(h)
        end
    end
    pool[handle] = nil
end

return function (handle, document, owner)
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
        o = constructor(document, handle, owner)
        _pool[handle] = o
    end
    return o
end
