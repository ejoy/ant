package.path = './?.lua'

local gui = require 'debugger.host.gui'
local core = require 'debugger.host.core'
local ev = require 'debugger.event'

core.initialize()

ev.on('run', function()
    gui.cleanarrow()
end)

ev.on('stop-position', function(path, line)
    local window = gui.openwindow(path)
    gui.setarrow(window, line)
end)

while true do
    if gui.update() then
        break
    end
    core.update()
end
