local rmlui = require "rmlui"

local elementFromPoint = rmlui.DocumentElementFromPoint
local getBody = rmlui.DocumentGetBody
local dispatchEvent = rmlui.ElementDispatchEvent
local getParent = rmlui.ElementGetParent
local setPseudoClass = rmlui.ElementSetPseudoClass
local project = rmlui.ElementProject

local m = {}

local width, height = 1, 1
local screen_ratio = 1.0
local documents = {}

local function round(x)
    return math.floor(x*screen_ratio+0.5)
end

function m.open(url)
    local doc = rmlui.DocumentCreate(url, width, height)
    if doc then
        table.insert(documents, 1, doc)
        return doc
    end
end

function m.onload(doc)
    dispatchEvent(getBody(doc), "load", {})
end

function m.close(doc)
    dispatchEvent(getBody(doc), "unload", {})
    for i, d in ipairs(documents) do
        if d == doc then
            table.remove(documents, i)
            break
        end
    end
end


local focusElement
local activeElement
local hoverElement = {}
local mouseX, mouseY
local MOUSE_DOWN <const> = 1
local MOUSE_MOVE <const> = 2
local MOUSE_UP   <const> = 3

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
    activeElement = nil
end

local function setActive(e)
    cancelActive()
    activeElement = walkElement(e)
    for _, element in ipairs(activeElement) do
        setPseudoClass(element, "active", true)
    end
end

local function setFocus(e)
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
    diff(oldHover, newHover, function (element)
        if dispatchEvent(element, "mouseout", event) then
            setPseudoClass(element, "hover", false)
        end
    end)
    diff(newHover, oldHover, function (element)
        if dispatchEvent(element, "mouseover", event) then
            setPseudoClass(element, "hover", true)
        end
    end)
    hoverElement = newHover
end

local function processMouseDown(doc, button, x, y)
    local e = elementFromPoint(doc, x, y)
    if not e then
        return
    end
    setFocus(e)
    setActive(e)
    local event = createMouseEvent(doc, e, button, x, y)
    dispatchEvent(e, "mousedown", event)
    return true
end

local function processMouseUp(doc, button, x, y)
    local e = elementFromPoint(doc, x, y)
    print("processMouseUp", x, y, e)
    if not e then
        return
    end
    local event = createMouseEvent(doc, e, button, x, y)
    local cancelled = not dispatchEvent(e, "mouseup", event)
    if cancelled then
        return true
    end
    if focusElement  == e then
        dispatchEvent(e, "click", event)
    end
    return true
end

local function processMouseMove(doc, button, x, y)
    local e = elementFromPoint(doc, x, y)
    if not e then
        return
    end
    local event = createMouseEvent(doc, e, button, x, y)
    local cancelled = not dispatchEvent(e, "mousemove", event)
    if cancelled then
        return true
    end
    updateHover(walkElement(e), event)
    return true
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
    for _, doc in ipairs(documents) do
        local handled = process(doc, button, x, y)
        if handled then
            return true
        end
    end
end

function m.process_touch(state, touches)
    local THOUCH_START  <const> = 1
    local THOUCH_MOVE   <const> = 2
    local THOUCH_END    <const> = 3
    local THOUCH_CANCEL <const> = 4
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
    print("dimensions", w, h, ratio)
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

function m.update()
    for _, doc in ipairs(documents) do
        rmlui.DocumentUpdate(doc)
    end
end

return m
