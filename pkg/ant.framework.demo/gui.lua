local ecs = ...
local world = ecs.world
local iRmlUi = ecs.require "ant.rmlui|rmlui_system"

local gui = {}

function gui.import_font(name)
	local font = import_package "ant.font"
	font.import(name)
end

function gui.open(html)
    iRmlUi.open(html)
end

function gui.on_message(what, func)
    iRmlUi.onMessage(what, func)
end

function gui.send(...)
	iRmlUi.sendMessage(...)
end

function gui.call(...)
	return iRmlUi.callMessage(...)
end

return gui