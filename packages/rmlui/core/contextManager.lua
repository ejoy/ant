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

local focusDocument
local focusElement
local activeElement
local hoverElement = {}
local mouseX, mouseY
local MOUSE_DOWN <const> = 1
local MOUSE_MOVE <const> = 2
local MOUSE_UP   <const> = 3

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
    if focusDocument == doc then
        focusElement = nil
    end
    hidden[doc] = nil
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

local function createMouseEvent(doc, e, button, x, y)
    local ev = {
        button = button >= 0 and button or nil,
        x = x,
        y = y,
    }
    local body = getBody(doc)
    ev.clientX, ev.clientY = x, y
    ev.offsetX, ev.offsetY = project(e, x, y)
    ev.pageX,   ev.pageY   = project(body, x, y)
    return ev
end

local function cancelActive()
    if not activeElement then
        return
    end
    for _, e in ipairs(activeElement) do
        if e._handle then
            setPseudoClass(e._handle, "active", false)
        end
    end
    activeElement = nil
end

local function setActive(doc, e)
    cancelActive()
    activeElement = walkElement(doc, e)
    for _, e in ipairs(activeElement) do
        setPseudoClass(e._handle, "active", true)
    end
end

local function setFocus(doc, e)
    focusDocument = doc
    focusElement = e
end

local function diff(a, b, f)
    for _, e in ipairs(a) do
        if b[e] == nil then
            f(e)
        end
    end
end

local function updateHover(newHover, event)
    local oldHover = hoverElement
    diff(oldHover, newHover, function (e)
        if e._handle and dispatchEvent(e._handle, "mouseout", event) then
            setPseudoClass(e._handle, "hover", false)
        end
    end)
    diff(newHover, oldHover, function (e)
        if e._handle and dispatchEvent(e._handle, "mouseover", event) then
            setPseudoClass(e._handle, "hover", true)
        end
    end)
    hoverElement = newHover
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

local function processMouseDown(doc, e, button, x, y)
    setFocus(doc, e)
    setActive(doc, e)
    local event = createMouseEvent(doc, e, button, x, y)
    dispatchEvent(e, "mousedown", event)
end

local function processMouseUp(doc, e, button, x, y)
    local event = createMouseEvent(doc, e, button, x, y)
    local cancelled = not dispatchEvent(e, "mouseup", event)
    if cancelled then
        return
    end
    -- TODO: fix mousedown/mouseup on different element
    -- if focusElement == e then
        dispatchEvent(e, "click", event)
    -- end
end

local function processMouseMove(doc, e, button, x, y)
    local event = createMouseEvent(doc, e, button, x, y)
    local cancelled = not dispatchEvent(e, "mousemove", event)
    if cancelled then
        return
    end
    updateHover(walkElement(doc, e), event)
end

function m.process_mouse(x, y, button, state)
    x, y = round(x), round(y)
    button = button - 1
    local process
    if state == MOUSE_DOWN then
        process = processMouseDown
    elseif state == MOUSE_MOVE then
        if mouseX == x and mouseY == y then
            return true
        end
        mouseX, mouseY = x, y
        process = processMouseMove
    elseif state == MOUSE_UP then
        cancelActive()
        process = processMouseUp
    else
        return
    end
    local doc, e = fromPoint(x, y)
    if e then
        process(doc, e, button, x, y)
        return true
    end
end

local touchData = {}

local function createTouchData(touch)
    return touch
end

local function push(t, v)
    t[#t+1] = v
end

local function dispatchTouchEvent(e, name)
    if not e._handle then
        return
    end
    local event = {
        changedTouches = {},
        targetTouches = {},
        touches = {},
    }
    for _, touch in pairs(touchData) do
        local data = createTouchData(touch)
        if touch.changed then
            push(event.changedTouches, data)
        end
        if not touch.removed then
            push(event.touches, data)
            if touch.target == e then
                push(event.targetTouches, data)
            end
        end
    end
    dispatchEvent(e._handle, name, event)
end

local function processTouchStart(touch)
    local doc, e = fromPoint(touch.x, touch.y)
    if e then
        touch.target = constructor.Element(doc, false, e)
        touch.changed = true
        touchData[touch.id] = touch
        return true
    end
end

local function processTouchMove(touch)
    local t = touchData[touch.id]
    if t then
        t.changed = true
        t.x = touch.x
        t.y = touch.y
        return true
    end
end

local function processTouchEnd(touch)
    local t = touchData[touch.id]
    if t then
        t.changed = true
        t.removed = true
        t.x = touch.x
        t.y = touch.y
        return true
    end
end

function m.process_touch(state, touches)
    local TOUCH_START  <const> = 1
    local TOUCH_MOVE   <const> = 2
    local TOUCH_END    <const> = 3
    local TOUCH_CANCEL <const> = 4
    local process
    local name
    if state == TOUCH_START then
        process = processTouchStart
        name = "touchstart"
    elseif state == TOUCH_MOVE then
        process = processTouchMove
        name = "touchmove"
    elseif state == TOUCH_END then
        process = processTouchEnd
        name = "touchend"
    elseif state == TOUCH_CANCEL then
        process = processTouchEnd
        name = "touchcancel"
    else
        return
    end
    local capture = false
    for _, touch in ipairs(touches) do
        if process(touch) then
            capture = true
        end
    end
    for _, touch in pairs(touchData) do
        if touch.changed then
            dispatchTouchEvent(touch.target, name)
        end
    end
    for _, touch in pairs(touchData) do
        touch.changed = nil
    end
    if state == TOUCH_CANCEL or state == TOUCH_END then
        for _, touch in ipairs(touches) do
            touchData[touch.id] = nil
        end
    end
    if capture then
        return true
    end
end

local gesture = {}
function gesture.tap(x, y)
    m.process_mouse(x, y, 1, MOUSE_MOVE)
    m.process_mouse(x, y, 1, MOUSE_DOWN)
    return m.process_mouse(x, y, 1, MOUSE_UP)
end

function m.process_gesture(name, ...)
    local f =  gesture[name]
    if not f then
        return
    end
    return f(...)
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
        if v.handle then
            rmlui.RenderSetTexture(v.path, v.handle, v.width, v.height)
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
