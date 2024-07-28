local rmlui = require "rmlui"
local event = require "core.event"
local environment = require "core.environment"
local textureloader = require "core.textureloader"
local constructor = require "core.DOM.constructor"
local eventListener = require "core.event.listener"
local datamodel = require "core.datamodel.api"
local task = require "core.task"
local fastio = require "fastio"
local vfs = require "vfs"

local elementFromPoint = rmlui.DocumentElementFromPoint
local getBody = rmlui.DocumentGetBody
local getParent = rmlui.NodeGetParent
local setPseudoClass = rmlui.ElementSetPseudoClass

local m = {}

local width, height = 1, 1
local screen_ratio = 1.0
local documents = {}
local hidden = {}
local pending = {}
local update
local default_view
local canvas_view
local ignore_canvas = true

function m.set_viewid(viewid)
	default_view = assert(viewid.main)
	canvas_view = assert(viewid.canvas)
end

function m.ignore_canvas(ignore)
	ignore_canvas = ignore
end

local function round(x)
    return math.floor(x+0.5)
end

local function createSandbox(document, name)
    local env = {
        window = constructor.Window(document, name),
        document = constructor.Document(document),
    }
    return setmetatable(env, {__index = _G})
end

local function notifyDocumentCreate(document, name)
    event("OnDocumentCreate", document)
    environment[document] = createSandbox(document, name)
end

local function notifyDocumentDestroy(document)
	event("OnDocumentDestroy", document)
	environment[document] = nil
end

local function readfile(path)
    local mem, symbol = vfs.read(path)
    if not mem then
        error(("`read `%s` failed."):format(path))
    end
    return mem, symbol
end

local function OnLoadInlineScript(document, source_path, content, source_line, ...)
    local env = environment[document]
    local source = "--@"..source_path..":"..source_line.."\n "..content
    local f, err = load(source, source, "t", env)
    if not f then
        log.warn(err)
        return
    end
    f(...)
end

local function OnLoadExternalScript(document, source_path, ...)
    local env = environment[document]
    local mem, symbol = readfile(source_path)
    local f, err = fastio.loadlua(mem, symbol, env)
    if not f then
        log.warn(("file '%s' load failed: %s."):format(source_path, err))
        return
    end
    f(...)
end

local function OnLoadInlineStyle(document, source_path, content, source_line)
    rmlui.DocumentLoadStyleSheet(document, source_path, content, source_line)
end

local function OnLoadExternalStyle(document, source_path)
    local mem = readfile(source_path)
    rmlui.DocumentLoadStyleSheet(document, source_path, fastio.wrap(mem))
end

function m.open(path, name, ...)
	local w,h
	if name == "canvas" then
		local canvas = require "core.canvas"
		w, h = canvas.size()
	else
		w, h = width, height
	end
    local doc = rmlui.DocumentCreate(w, h)
    if not doc then
        return
    end
	if name == "canvas" then
		documents.canvas = doc
	else
	    documents[#documents+1] = doc
	end
    notifyDocumentCreate(doc, name)
    local mem, symbol = readfile(path)
    local html = rmlui.DocumentParseHtml(path, fastio.wrap(mem), false)
    if not html then
        m.close(doc)
        return
    end
    local scripts = rmlui.DocumentInstanceHead(doc, html)
    for _, load in ipairs(scripts) do
        local type, str, line = load[1], load[2], load[3]
        if type == "script" then
            if line then
                OnLoadInlineScript(doc, symbol, str, line, ...)
            else
                OnLoadExternalScript(doc, str, ...)
            end
        elseif type == "style" then
            if line then
                OnLoadInlineStyle(doc, symbol, str, line)
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
    if update then
        task.new(function ()
            m.close(doc)
        end)
        return
    end
    eventListener.dispatch(doc, getBody(doc), "unload", {})
    notifyDocumentDestroy(doc)
    rmlui.DocumentDestroy(doc)
	if doc == documents.canvas then
		documents.canvas = nil
	else
		for i, d in ipairs(documents) do
			if d == doc then
				table.remove(documents, i)
				break
			end
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
local active_gesture = {}

function gesture.tap(doc, e, ev)
    eventListener.dispatch(doc, e, "click", ev)
end

function gesture.longpress(doc, e, ev)
    eventListener.dispatch(doc, e, "longpress", ev)
end

function gesture.pan(doc, e, ev)
    ev.velocity_x = round(ev.velocity_x)
    ev.velocity_y = round(ev.velocity_y)
    eventListener.dispatch(doc, e, "pan", ev)
end

function gesture.pinch(doc, e, ev)
    ev.velocity = round(ev.velocity)
    eventListener.dispatch(doc, e, "pinch", ev)
end

function gesture.swipe(doc, e, ev)
    eventListener.dispatch(doc, e, "swipe", ev)
end

function m.process_gesture(ev)
    local active = active_gesture[ev.what]
    if active then
        if ev.state == "ended" then
            active_gesture[ev.what] = nil
        end
        local func = gesture[ev.what]
        local doc, e = active[1], active[2]
        ev.x = round(ev.x)
        ev.y = round(ev.y)
        func(doc, e, ev)
        return true
    end
    if active == false then
        if ev.state == "ended" then
            active_gesture[ev.what] = nil
        end
        return
    end
    local x, y = round(ev.x), round(ev.y)
    local doc, e = fromPoint(x, y)
    if e then
        if ev.state == "began" then
            active_gesture[ev.what] = { doc, e }
        end
        ev.x = x
        ev.y = y
        local func = gesture[ev.what]
        func(doc, e, ev)
        return true
    else
        if ev.state == "began" then
            active_gesture[ev.what] = false
        end
        return
    end
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
    return true
end

local function setActive(doc, e, id)
    cancelActive(id)
    local actives = walkElement(doc, e)
    activeElement[id] = actives
    for _, e in ipairs(actives) do
        setPseudoClass(e._handle, "active", true)
    end
end

function m.process_touch(ev)
    if ev.state == "began" then
        local x, y = round(ev.x), round(ev.y)
        local doc, e = fromPoint(x, y)
        if e then
            setActive(doc, e, ev.id)
            return true
        end
    elseif ev.state == "ended" or ev.state == "cancelled" then
        if cancelActive(ev.id) then
            return true
        end
    elseif ev.state == "moved" then
        if activeElement[ev.id] then
            return true
        end
    end
end

local active_hover = {}

local function set_hover(doc, e, ev)
	if e == active_hover.e and doc == active_hover.doc then
		-- todo : hover mouse moved
	else
		if active_hover.e then
			ev.state = "leave"
		    eventListener.dispatch( active_hover.doc, active_hover.e, "hover", ev)
		end
		active_hover.doc = doc
		active_hover.e = e
		if e then
			ev.state = "enter"
		    eventListener.dispatch( doc, e, "hover", ev)
		end
	end
end

function m.process_hover(ev)
	local x, y = round(ev.x), round(ev.y)
	local doc, e = fromPoint(x, y)
	set_hover(doc, e, ev)
end

function m.set_viewport(vr)
    local w = vr.w
    local h = vr.h
    if w == width and h == height then
        return
    end
    width, height = w, h
    for _, doc in ipairs(documents) do
        rmlui.DocumentSetDimensions(doc, width, height)
        eventListener.dispatch(doc, getBody(doc), "resize", {})
    end
end

function m.updatePendingTexture(doc, v)
    if not doc then
        return
    end
    if pending[doc] then
        local newv = pending[doc] + v
        if newv == 0 then
            pending[doc] = nil
        else
            pending[doc] = newv
        end
    else
        pending[doc] = v
    end
end

function m.getPendingTexture(doc)
    return pending[doc] or 0
end

local function parse_atlas(width, height, atlas)
	local uv_rect, vertex_factor = {}, {}
    uv_rect.x, uv_rect.y, uv_rect.w, uv_rect.h = atlas.x / width, atlas.y / height, (atlas.dw - 2) / width, (atlas.dh - 2)/ height
    vertex_factor.x, vertex_factor.y = atlas.dx / atlas.w, atlas.dy / atlas.h
    vertex_factor.w, vertex_factor.h = (atlas.dw - 2) / atlas.w, (atlas.dh - 2) / atlas.h
    return {
        w = atlas.w, h = atlas.h, 
        ax = uv_rect.x, ay = uv_rect.y, aw = uv_rect.w, ah = uv_rect.h,
        fx = vertex_factor.x, fy = vertex_factor.y, fw = vertex_factor.w, fh = vertex_factor.h,
    }
end

local function parse_lattice(lattice)
	local new_lattice = {}
	for k, v in pairs(lattice) do
		new_lattice[k] = v / 100
	end
	return new_lattice
end

local function updateTexture()
    local q = textureloader.updateTexture()
    if not q then
        return
    end
    for i = 1, #q do
        local v = q[i]
        if v.id then
            if v.lattice then
                local nl = parse_lattice(v.lattice)
                rmlui.RenderSetLatticeTexture(v.path, v.id, v.width, v.height, nl.x1, nl.y1, nl.x2, nl.y2, nl.u, nl.v)
            elseif v.atlas then
                local at = parse_atlas(v.width, v.height, v.atlas.rect)
                rmlui.RenderSetTextureAtlas(v.path, v.id, at.w, at.h, at.ax, at.ay, at.aw, at.ah, at.fx, at.fy, at.fw, at.fh)
            else
                rmlui.RenderSetTexture(v.path, v.id, v.width, v.height)
            end
            for _, e in ipairs(v.elements) do
                if e._handle then
                    rmlui.ElementDirtyImage(e._handle)
                end
                m.updatePendingTexture(e._document, -1)
            end
        else
            rmlui.RenderSetTexture(v.path)
        end
    end
end

function m.update(delta)
    updateTexture()
    update = true
    rmlui.RenderBegin()
    for _, doc in ipairs(documents) do
        if not hidden[doc] then
            datamodel.update(doc)
            rmlui.DocumentUpdate(doc, delta)
        end
    end
	if not ignore_canvas then
		local canvas_doc = documents.canvas
		if canvas_doc then
			rmlui.RenderSetView(canvas_view)
--			print ("RenderSetView", canvas_view)
			datamodel.update(canvas_doc)
			rmlui.DocumentUpdate(canvas_doc, delta)
			rmlui.RenderSetView(default_view)
		end
	end
	rmlui.RenderFrame()
    update = nil
end

return m
