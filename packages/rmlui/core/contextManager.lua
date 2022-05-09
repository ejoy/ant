local rmlui = require "rmlui"
local event = require "core.event"
local environment = require "core.environment"
local createSandbox = require "core.sandbox.create"

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

local focusDocument
local focusElement
local activeDocument
local activeElement
local hoverDocument
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

local function invalidElement(doc, e)
    local res = {}
    event("InvalidElement", doc, e, res)
    return res.ok
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
    if activeDocument == doc then
        activeElement = nil
    end
    if hoverDocument == doc then
        hoverElement = {}
    end
end

local function walkElement(e)
    local r = {}
    while true do
        r[#r+1] = e
        r[e] = true
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
    for _, element in ipairs(activeElement) do
        setPseudoClass(element, "active", false)
    end
    activeDocument = nil
    activeElement = nil
end

local function setActive(doc, e)
    cancelActive()
    activeDocument = doc
    activeElement = walkElement(e)
    for _, element in ipairs(activeElement) do
        setPseudoClass(element, "active", true)
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

local function updateHover(doc, newHover, event)
    local oldHover = hoverElement
    diff(oldHover, newHover, function (element)
        if invalidElement(doc, element) and dispatchEvent(element, "mouseout", event) then
            setPseudoClass(element, "hover", false)
        end
    end)
    diff(newHover, oldHover, function (element)
        if invalidElement(doc, element) and dispatchEvent(element, "mouseover", event) then
            setPseudoClass(element, "hover", true)
        end
    end)
    hoverDocument = doc
    hoverElement = newHover
end

local function fromPoint(x, y)
    for i = #documents, 1, -1 do
        local doc = documents[i]
        local e = elementFromPoint(doc, x, y)
        if e then
            return doc, e
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
    if focusElement == e then
        dispatchEvent(e, "click", event)
    end
end

local function processMouseMove(doc, e, button, x, y)
    local event = createMouseEvent(doc, e, button, x, y)
    local cancelled = not dispatchEvent(e, "mousemove", event)
    if cancelled then
        return
    end
    updateHover(doc, walkElement(e), event)
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

local function dispatchTouchEvent(doc, e, name)
    if not invalidElement(doc, e) then
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
    dispatchEvent(e, name, event)
end

local function processTouchStart(touch)
    local doc, e = fromPoint(touch.x, touch.y)
    if e then
        touch.target_doc = doc
        touch.target = e
        touch.changed = true
        touchData[touch.id] = touch
    end
end

local function processTouchMove(touch)
    local t = touchData[touch.id]
    if t then
        t.changed = true
        t.x = touch.x
        t.y = touch.y
    end
end

local function processTouchEnd(touch)
    local t = touchData[touch.id]
    if t then
        t.changed = true
        t.removed = true
        t.x = touch.x
        t.y = touch.y
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
    for _, touch in ipairs(touches) do
        process(touch)
    end
    for _, touch in pairs(touchData) do
        if touch.changed then
            dispatchTouchEvent(touch.target_doc, touch.target, name)
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

function m.update(delta)
    rmlui.RenderBegin()
    for _, doc in ipairs(documents) do
        rmlui.DocumentUpdate(doc, delta)
    end
    rmlui.RenderFrame()
end

return m
