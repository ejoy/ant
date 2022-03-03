local rmlui = require "rmlui"
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
        rmlui.DocumentShow(doc)
        return doc
    end
end

function m.onload(doc)
    rmlui.DocumentOnLoad(doc)
end

function m.close(doc)
    rmlui.DocumentClose(doc)
    for i, d in ipairs(documents) do
        if d == doc then
            table.remove(documents, i)
            break
        end
    end
end

function m.process_mouse(x, y, type, state)
    x, y = round(x), round(y)
    type, state = type-1, state-1
    for _, doc in ipairs(documents) do
        local handled = rmlui.DocumentProcessMouse(doc, type, state, x, y)
        if handled then
            return true
        end
    end
end

function m.process_touch(state, touches)
    state = state-1
    for _, doc in ipairs(documents) do
        local handled = rmlui.DocumentProcessTouch(doc, state, touches)
        if handled then
            return true
        end
    end
end

local gesture = {}
function gesture.tap(x, y)
    x, y = round(x), round(y)
    local DOWN <const> = 0
    local MOVE <const> = 1
    local UP   <const> = 2
    m.process_mouse(x, y, 0, MOVE)
    m.process_mouse(x, y, 0, DOWN)
    return m.process_mouse(x, y, 0, UP)
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
    end
end

function m.update()
    for _, doc in ipairs(documents) do
        rmlui.DocumentUpdate(doc)
    end
end

return m
