local rmlui = require "rmlui"
local ltask = require "ltask"
local event = require "core.event"
local timer = require "core.timer"
local task = require "core.task"
local document_manager = require "core.document_manager"
local datamodel = require "core.datamodel.api"
local environment = require "core.environment"
local eventListener = require "core.event.listener"

local function createWindow(document, source)
    --TODO: pool
    local window = {}
    local timer_object = setmetatable({}, {__mode = "k"})
    function window.createModel(view)
        return datamodel.create(document, view)
    end
    function window.open(url)
        local newdoc = document_manager.open(url)
        if not newdoc then
            return
        end
        document_manager.onload(newdoc)
        return createWindow(newdoc, document)
    end
    function window.close()
        document_manager.close(document)
        for t in pairs(timer_object) do
            t:remove()
        end
    end
    function window.show()
        document_manager.show(document)
    end
    function window.hide()
        document_manager.hide(document)
    end
    function window.flush()
        document_manager.flush(document)
    end
    function window.requestAnimationFrame(f)
        task.new(f)
    end
    function window.setTimeout(f, delay)
        local t = timer.wait(delay, f)
        timer_object[t] = true
        return t
    end
    function window.setInterval(f, delay)
        local t = timer.loop(delay, f)
        timer_object[t] = true
        return t
    end
    function window.clearTimeout(t)
        t:remove()
    end
    function window.clearInterval(t)
        t:remove()
    end
    function window.getPendingTexture()
        return document_manager.getPendingTexture(document)
    end
    function window.addEventListener(type, func)
        eventListener.add(document, rmlui.DocumentGetBody(document), type, func)
    end
    function window.postMessage(data)
        local eventData = {
            data = data,
        }
        if source == nil then
            eventData.source = environment[document].window
        elseif source == "extern" then
            eventData.source = environment[document].window.extern
        else
            eventData.source = createWindow(source, document)
        end
        eventListener.dispatch(document, rmlui.DocumentGetBody(document), "message", eventData)
    end
    if source == nil then
        window.extern = {
            postMessage = function (data)
                local name = environment[document]._extern_name
                if name then
                    task.new(function ()
                        ltask.send(ServiceWorld, "rmlui_message", name, data)
                    end)
                end
            end
        }
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

return createWindow
