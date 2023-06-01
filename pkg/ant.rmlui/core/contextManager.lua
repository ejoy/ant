local rmlui = require "rmlui"
local event = require "core.event"
local environment = require "core.environment"
local createSandbox = require "core.sandbox.create"
local filemanager = require "core.filemanager"
local constructor = require "core.DOM.constructor"

local elementFromPoint = rmlui.DocumentElementFromPoint
local getBody = rmlui.DocumentGetBody
local dispatchEvent = rmlui.ElementDispatchEvent
local getParent = rmlui.NodeGetParent
local setPseudoClass = rmlui.ElementSetPseudoClass
local project = rmlui.ElementProject

local m = {}

local width, height = 1, 1
local screen_ratio = 1.0
local documents = {}
local hidden = {}

local function round(x)
    return math.floor(x*screen_ratio+0.5)
end

local function notifyDocumentCreate(document)
	local globals = createSandbox()
	event("OnDocumentCreate", document, globals)
	globals.window.document = globals.document
	environment[document] = globals
end

local function notifyDocumentDestroy(document)
	event("OnDocumentDestroy", document)
	environment[document] = nil
end

function m.open(url)
    local doc = rmlui.DocumentCreate(width, height)
    if not doc then
        return
    end
    documents[#documents+1] = doc
    notifyDocumentCreate(doc)
    local ok = rmlui.DocumentLoad(doc, url)
    if not ok then
        m.close(doc)
        return
    end
    return doc
end

function m.onload(doc)
    --TODO
    dispatchEvent(getBody(doc), "load", {})
end

function m.show(doc)
    hidden[doc] = nil
end

function m.hide(doc)
    hidden[doc] = true
end

function m.close(doc)
    dispatchEvent(getBody(doc), "unload", {})
    notifyDocumentDestroy(doc)
    rmlui.DocumentDestroy(doc)
    for i, d in ipairs(documents) do
        if d == doc then
            table.remove(documents, i)
            break
        end
    end
    hidden[doc] = nil
end

local function fromPoint(x, y)
    for i = #documents, 1, -1 do
        local doc = documents[i]
        if not hidden[doc] then
            local e = elementFromPoint(doc, x, y)
            if e then
                return doc, e
            end
        end
    end
end

local gesture = {}

local function createClickEvent(doc, e, x, y)
    local ev = {
        x = x,
        y = y,
    }
    local body = getBody(doc)
    ev.clientX, ev.clientY = x, y
    ev.offsetX, ev.offsetY = project(e, x, y)
    ev.pageX,   ev.pageY   = project(body, x, y)
    return ev
end

function gesture.tap(ev)
    local x, y = round(ev.x), round(ev.y)
    local doc, e = fromPoint(x, y)
    if e then
        dispatchEvent(e, "click", createClickEvent(doc, e, x, y))
        dispatchEvent(e, "tap", {
            x = x,
            y = y,
        })
        return true
    end
end

function gesture.long_press(ev)
    local x, y = round(ev.x), round(ev.y)
    local _, e = fromPoint(x, y)
    if e then
        dispatchEvent(e, "long_press", {
            x = x,
            y = y,
        })
        return true
    end
end

function gesture.pan(ev)
    local x, y = round(ev.x), round(ev.y)
    local _, e = fromPoint(x, y)
    if e then
        dispatchEvent(e, "pan", {
            x = x,
            y = y,
            dx = round(ev.dx),
            dy = round(ev.dy),
            vx = round(ev.vx),
            vy = round(ev.vy),
        })
        return true
    end
end

function gesture.pinch(ev)
    local x, y = round(ev.x), round(ev.y)
    local _, e = fromPoint(x, y)
    if e then
        dispatchEvent(e, "pinch", {
            x = x,
            y = y,
            state = ev.state,
            velocity = ev.velocity,
        })
        return true
    end
end

function m.process_gesture(name, ...)
    local f =  gesture[name]
    if not f then
        return
    end
    return f(...)
end

local function walkElement(doc, e)
    local r = {}
    while true do
        local element = constructor.Element(doc, false, e)
        r[#r+1] = element
        r[element] = true
        e = getParent(e)
        if not e then
            break
        end
    end
    return r
end

local activeElement = {}

local function cancelActive(id)
    local actives = activeElement[id]
    if not actives then
        return
    end
    for _, e in ipairs(actives) do
        if e._handle then
            setPseudoClass(e._handle, "active", false)
        end
    end
    activeElement[id] = nil
end

local function setActive(doc, e, id)
    cancelActive(id)
    local actives = walkElement(doc, e)
    activeElement[id] = actives
    for _, e in ipairs(actives) do
        setPseudoClass(e._handle, "active", true)
    end
end

function m.process_touch(id, state, x, y)
    local TOUCH_BEGAN <const> = 1
    local TOUCH_MOVED <const> = 2
    local TOUCH_ENDED <const> = 3
    local TOUCH_CANCELLED <const> = 4
    if state == TOUCH_BEGAN then
        x, y = round(x), round(y)
        local doc, e = fromPoint(x, y)
        if e then
            setActive(doc, e, id)
        end
    elseif state == TOUCH_ENDED or state == TOUCH_CANCELLED then
        cancelActive(id)
    elseif state == TOUCH_MOVED then
        return
    end
end

function m.set_dimensions(w, h, ratio)
    screen_ratio = ratio
    if w == width and h == height then
        return
    end
    width, height = w, h
    for _, doc in ipairs(documents) do
        rmlui.DocumentSetDimensions(doc, width, height)
        dispatchEvent(getBody(doc), "resize", {})
    end
end

local function updateTexture()
    local q = filemanager.updateTexture()
    if not q then
        return
    end
    for i = 1, #q do
        local v = q[i]
        if v.id then
            rmlui.RenderSetTexture(v.path, v.id, v.width, v.height)
            for _, e in ipairs(v.elements) do
                if e._handle then
                    rmlui.ElementDirtyImage(e._handle)
                end
            end
        else
            rmlui.RenderSetTexture(v.path)
        end
    end
end

function m.update(delta)
    updateTexture()
    rmlui.RenderBegin()
    for _, doc in ipairs(documents) do
        if not hidden[doc] then
            rmlui.DocumentUpdate(doc, delta)
        end
    end
    rmlui.RenderFrame()
end

return m
