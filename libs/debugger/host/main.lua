package.path = './?.lua'

local gui = require 'debugger.host.gui'
local request = require 'debugger.host.request'
local core = require 'debugger.host.core'
local ev = require 'debugger.event'

core.initialize()

ev.on('host-running', function()
    gui.btn_stop()
    gui.cleanarrow()
end)

ev.on('host-stopped', function(source, line)
    gui.btn_run()
    if source.path then
        local title = source.path
        local wnd, exist = gui.openwindow(title)
        if not exist then
            local f = assert(io.open(source.path, 'r'))
            local text = f:read 'a'
            f:close()
            gui.settext(wnd, text)
        end
        gui.setarrow(wnd, line)
    elseif source.sourceReference then
        local title = ('<Memory>:%d'):format(source.sourceReference)
        local wnd, exist = gui.openwindow(title)
        if exist then
            gui.setarrow(wnd, line)
        else
            request.task(function()
                local ok, res = request.wait(request.source(source.sourceReference))
                if ok then
                    gui.settext(wnd, res.content)
                    gui.setarrow(wnd, line)
                end
            end)
        end
    end
end)


while true do
    if gui.update() then
        break
    end
    core.update()
end
