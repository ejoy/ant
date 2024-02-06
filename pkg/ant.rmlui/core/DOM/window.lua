local rmlui = require "rmlui"
local timer = require "core.timer"
local task = require "core.task"
local event = require "core.event"
local document_manager = require "core.document_manager"
local datamodel = require "core.datamodel.api"
local eventListener = require "core.event.listener"
local message = require "core.message"

local createWindowByPool

local function createWindow(document, name)
    local window = { invaild = false }
    local timer_object = setmetatable({}, {__mode = "k"})
    function window.createModel(view)
        if window.invaild then
            return
        end
        return datamodel.create(document, view)
    end
    function window.open(url, ...)
        if window.invaild then
            return
        end
        local newdoc = document_manager.open(url, nil, ...)
        if not newdoc then
            return
        end
        document_manager.onload(newdoc)
        return createWindowByPool(newdoc)
    end
    function window.close()
        if window.invaild then
            return
        end
        document_manager.close(document)
        for t in pairs(timer_object) do
            t:remove()
        end
    end
    function window.show()
        if window.invaild then
            return
        end
        document_manager.show(document)
    end
    function window.hide()
        if window.invaild then
            return
        end
        document_manager.hide(document)
    end
    function window.flush()
        if window.invaild then
            return
        end
        document_manager.flush(document)
    end
    function window.requestAnimationFrame(f)
        if window.invaild then
            return
        end
        task.new(f)
    end
    function window.setTimeout(f, delay)
        if window.invaild then
            return
        end
        local t = timer.wait(delay, f)
        timer_object[t] = true
        return t
    end
    function window.setInterval(f, delay)
        if window.invaild then
            return
        end
        local t = timer.loop(delay, f)
        timer_object[t] = true
        return t
    end
    function window.clearTimeout(t)
        if window.invaild then
            return
        end
        t:remove()
    end
    function window.clearInterval(t)
        if window.invaild then
            return
        end
        t:remove()
    end
    function window.getPendingTexture()
        if window.invaild then
            return
        end
        return document_manager.getPendingTexture(document)
    end
    function window.addEventListener(type, func)
        if window.invaild then
            return
        end
        eventListener.add(document, rmlui.DocumentGetBody(document), type, func)
    end
    function window.onMessage(what, func)
        if window.invaild then
            return
        end
        message.on(what, func)
    end
    function window.getName()
        if window.invaild then
            return
        end
        return name
    end
    function window.callMessage(...)
        if window.invaild then
            return
        end
        return message.call(ServiceWindow, ...)
    end
    function window.sendMessage(...)
        if window.invaild then
            return
        end
        message.send(ServiceWindow, ...)
    end
    local ctors = {}
    local customElements = {}
    function customElements.define(name, ctor)
        if ctors[name] then
            error "Already contains a custom element with the same name."
        end
        if not name:match "[a-z][0-9a-z_%-]*" then
            error "Invalid custom element name."
        end
        if type(ctor) ~= "function" then
            error "Invalid constructor."
        end
        ctors[name] = ctor
    end
    function customElements.get(name)
        return ctors[name]
    end
    window.customElements = customElements
    local mt = {}
    function mt:__newindex(name, f)
        if name == "onload" then
            rawset(self, "onload", f)
            self.addEventListener("load", f)
        end
    end
    return setmetatable(window, mt)
end

local pool = {}

function event.OnDocumentDestroy(handle)
    local o = pool[handle]
    if o then
        o.invaild = true
    end
    pool[handle] = nil
end

function createWindowByPool(document, name)
    local o = pool[document]
    if o then
        return o
    end
    o = createWindow(document, name)
    pool[document] = o
    return o
end

return createWindowByPool
