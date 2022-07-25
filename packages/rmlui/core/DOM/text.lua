local rmlui = require "rmlui"
local event = require "core.event"
local constructor = require "core.DOM.constructor"

local constructorText

local property_init = {}
local property_getter = {}
local property_setter = {}


function property_init:cloneNode()
    return function ()
        local document = self._document
        local handle = self._handle
        return constructor.Node(document, true, rmlui.NodeClone(handle))
    end
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
    return constructor.Element(document, false, rmlui.NodeGetParent(handle))
end

function property_getter:textContent()
    return rmlui.TextGetText(self._handle)
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
    return rmlui.TextGetText(self._handle)
end

local pool = {}

function event.OnDocumentDestroy(handle)
    if not pool[handle] then
        return
    end
    for h, e in pairs(pool[handle]) do
        if e._owner then
            rmlui.TextDelete(h)
        end
        e._document = nil
        e._handle = nil
    end
    pool[handle] = nil
end

function constructorText(document, owner, handle)
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

return constructorText
