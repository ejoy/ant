local rmlui = require "rmlui"
local event = require "core.event"
local environment = require "core.environment"
local createSandbox = require "core.sandbox.create"
local filemanager = require "core.filemanager"
local constructor = require "core.DOM.constructor"
local eventListener = require "core.event.listener"
local console = require "core.sandbox.console"
local datamodel = require "core.datamodel.api"

local elementFromPoint = rmlui.DocumentElementFromPoint
local getBody = rmlui.DocumentGetBody
local getParent = rmlui.NodeGetParent
local setPseudoClass = rmlui.ElementSetPseudoClass

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

local function OnLoadInlineScript(document, source_path, content, source_line)
	local f, err = filemanager.loadstring(content, source_path, source_line, environment[document])
	if not f then
		console.warn(err)
		return
	end
	f()
end

local function OnLoadExternalScript(document, source_path)
	local f, err = filemanager.loadfile(source_path, environment[document])
	if not f then
		console.warn(("file '%s' load failed: %s."):format(source_path, err))
		return
	end
	f()
end

local function OnLoadInlineStyle(document, source_path, content, source_line)
    rmlui.DocumentLoadStyleSheet(document, source_path, content, source_line)
end

local function OnLoadExternalStyle(document, source_path)
    if not rmlui.DocumentLoadStyleSheet(document, source_path) then
        rmlui.DocumentLoadStyleSheet(document, source_path, filemanager.readfile(source_path))
    end
end

function m.open(path)
    local doc = rmlui.DocumentCreate(width, height, path)
    if not doc then
        return
    end
    documents[#documents+1] = doc
    notifyDocumentCreate(doc)
    local data = filemanager.readfile(path)
    local html = rmlui.DocumentParseHtml(path, data, false)
    if not html then
        m.close(doc)
        return
    end
    local scripts = rmlui.DocumentInstanceHead(doc, html)
    for _, load in ipairs(scripts) do
        local type, str, line = load[1], load[2], load[3]
        if type == "script" then
            if line then
                OnLoadInlineScript(doc, path, str, line)
            else
                OnLoadExternalScript(doc, str)
            end
        elseif type == "style" then
            if line then
                OnLoadInlineStyle(doc, path, str, line)
            else
                OnLoadExternalStyle(doc, str)
            end
        end
    end
    rmlui.DocumentInstanceBody(doc, html)
    datamodel.update(doc)
    rmlui.DocumentFlush(doc)
    return doc
end

function m.onload(doc)
    --TODO
    eventListener.dispatch(doc, getBody(doc), "load", {})
end

function m.show(doc)
    hidden[doc] = nil
end

function m.hide(doc)
    hidden[doc] = true
end

function m.flush(doc)
    datamodel.update(doc)
    rmlui.DocumentFlush(doc)
end

function m.close(doc)
    eventListener.dispatch(doc, getBody(doc), "unload", {})
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

function gesture.tap(ev)
    local x, y = round(ev.x), round(ev.y)
    local doc, e = fromPoint(x, y)
    if e then
        eventListener.dispatch(doc, e, "click", {
            x = x,
            y = y,
        })
        return true
    end
end

function gesture.longpress(ev)
    local x, y = round(ev.x), round(ev.y)
    local doc, e = fromPoint(x, y)
    if e then
        eventListener.dispatch(doc, e, "longpress", {
            x = x,
            y = y,
        })
        return true
    end
end

function gesture.pan(ev)
    local x, y = round(ev.x), round(ev.y)
    local doc, e = fromPoint(x, y)
    if e then
        eventListener.dispatch(doc, e, "pan", {
            state = ev.state,
            x = x,
            y = y,
            dx = round(ev.dx),
            dy = round(ev.dy),
        })
        return true
    end
end

function gesture.pinch(ev)
    local x, y = round(ev.x), round(ev.y)
    local doc, e = fromPoint(x, y)
    if e then
        eventListener.dispatch(doc, e, "pinch", {
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
        eventListener.dispatch(doc, getBody(doc), "resize", {})
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
            datamodel.update(doc)
            rmlui.DocumentUpdate(doc, delta)
        end
    end
    rmlui.RenderFrame()
end

return m
