local rmlui = require "rmlui"
local event = require "core.event"
local constructor = require "core.DOM.constructor"
local eventListener = require "core.event.listener"

local constructorElement

local attribute_mt = {}
function attribute_mt:__index(name)
    return rmlui.ElementGetAttribute(self._object._handle, name)
end
function attribute_mt:__newindex(name, v)
    if v == nil then
        rmlui.ElementRemoveAttribute(self._object._handle, name)
    else
        rmlui.ElementSetAttribute(self._object._handle, name, v)
    end
end

local style_mt = {}
function style_mt:__index(name)
    return rmlui.ElementGetProperty(self._object._handle, name)
end
function style_mt:__newindex(name, value)
    if value == nil then
        rmlui.ElementSetProperty(self._object._handle, name)
    elseif type(value) == "string" then
        rmlui.ElementSetProperty(self._object._handle, name, value)
    else
        rmlui.ElementSetProperty(self._object._handle, name, tostring(value))
    end
end

local property_init = {}
local property_getter = {}
local property_setter = {}

function property_init:addEventListener()
    return function (type, func)
        return eventListener.add(self._document, self._handle, type, func)
    end
end

function property_init:removeEventListener()
    return function (id)
        eventListener.remove(self._document, self._handle, id)
    end
end

function property_init:ownerDocument()
    return constructor.Document(self._document)
end

local childnodes_mt = {}
function childnodes_mt:__len()
    local handle = self._object._handle
    return rmlui.ElementGetChildren(handle)
end
function childnodes_mt:__index(i)
    local document = self._object._document
    local handle = self._object._handle
    return constructor.Node(document, false, rmlui.ElementGetChildren(handle, i-1))
end
function childnodes_mt:__pairs()
    local i = 0
    return function ()
        i = i + 1
        return self[i]
    end
end

function property_init:childNodes()
    return setmetatable({
        _object = self,
    }, childnodes_mt)
end

function property_init:dispatchEvent()
    return function (eventname, eventData)
        eventListener.dispatch(self._document, self._handle, eventname, eventData)
    end
end

function property_init:removeChild()
    return function (child)
        local handle = self._handle
        child._owner = nil
        if child._handle then
            rmlui.ElementRemoveChild(handle, child._handle)
        end
    end
end

function property_init:removeAllChild()
    return function ()
        local handle = self._handle
        rmlui.ElementRemoveAllChildren(handle)
    end
end

function property_init:appendChild()
    return function (child, index)
        local handle = self._handle
        child._owner = nil
        rmlui.ElementAppendChild(handle, child._handle, index)
    end
end

function property_init:cloneNode()
    return function ()
        local document = self._document
        local handle = self._handle
        return constructor.Node(document, true, rmlui.NodeClone(handle))
    end
end

function property_init:getElementById()
    return function (id)
        local document = self._document
        local handle = self._handle
        return constructorElement(document, false, rmlui.ElementGetElementById(handle, id))
    end
end

function property_init:getElementsByTagName()
    return function (tag_name)
        local document = self._document
        local handle = self._handle
        local list = rmlui.ElementGetElementsByTagName(handle, tag_name)
        for i, e in ipairs(list) do
            list[i] = constructorElement(document, false, e)
        end
        return list
    end
end

function property_init:getElementsByClassName()
    return function (class_name)
        local document = self._document
        local handle = self._handle
        local list = rmlui.ElementGetElementsByClassName(handle, class_name)
        for i, e in ipairs(list) do
            list[i] = constructorElement(document, false, e)
        end
        return list
    end
end

function property_init:scrollInsets()
    return function (l, t, r, b)
        local handle = self._handle
        rmlui.ElementSetScrollInsets(handle, l, t, r, b)
    end
end

function property_init:getAttribute()
    return function (name)
        local handle = self._handle
        return rmlui.ElementGetAttribute(handle, name)
    end
end

function property_init:setAttribute()
    return function (name, value)
        local handle = self._handle
        rmlui.ElementGetAttribute(handle, name, value)
    end
end

function property_init:style()
    return setmetatable({_object = self}, style_mt)
end

function property_init:attributes()
    return setmetatable({_object = self}, attribute_mt)
end

for name, init in pairs(property_init) do
    property_getter[name] = function (self)
        local v = init(self)
        rawset(self, name, v)
        return v
    end
end

function property_getter:parentNode()
    local document = self._document
    local handle = self._handle
    return constructorElement(document, false, rmlui.NodeGetParent(handle))
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
    return rmlui.ElementGetId(self._handle)
end
function property_setter:id(v)
    rmlui.ElementSetId(self._handle, v)
end

function property_getter:tagName()
    return rmlui.ElementGetTagName(self._handle)
end

function property_getter:className()
    return rmlui.ElementGetClassName(self._handle)
end
function property_setter:className(v)
    rmlui.ElementSetClassName(self._handle, v)
end

function property_getter:innerHTML()
    return rmlui.ElementGetInnerHTML(self._handle)
end
function property_setter:innerHTML(v)
    rmlui.ElementSetInnerHTML(self._handle, v)
end

function property_getter:outerHTML()
    return rmlui.ElementGetOuterHTML(self._handle)
end
function property_setter:outerHTML(v)
    rmlui.ElementSetOuterHTML(self._handle, v)
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
        error("property `" .. name .. "` readonly.")
    end
    rawset(self, name, value)
end

function property_mt:__tostring()
    return rmlui.ElementGetOuterHTML(self._handle)
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
        e._document = nil
        e._handle = nil
    end
    pool[handle] = nil
end

function event.OnDestroyNode(handle, node)
    if not pool[handle] then
        return
    end
    local e = pool[handle][node]
    if e then
        e._handle = nil
    end
    pool[handle][node] = nil
end

function constructorElement(document, owner, handle)
    if handle == nil then
        return
    end
    local _pool = pool[document]
    if not _pool then
        _pool = {}
        pool[document] = _pool
    end
    local o = _pool[handle]
    if not o then
        o = setmetatable({
            _handle = handle,
            _document = document,
            _owner = owner,
        }, property_mt)
        _pool[handle] = o
    end
    return o
end

return constructorElement
