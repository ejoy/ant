local rmlui = require "rmlui"
local environment = require "core.environment"

return function (e)
	if e.target then
		local constructorElement = require "core.DOM.element"
		local document = rmlui.ElementGetOwnerDocument(e.target)
		e.target = constructorElement(document, false, e.target)
		e.current = constructorElement(document, false, e.current)
		if e.type == "message" then
			local createWindow = require "core.DOM.window"
			if e.source == nil then
				e.source = environment[document].window
			elseif e.source == "extern" then
				e.source = environment[document].window.extern
			else
				e.source = createWindow(e.source, document)
			end
		end
	end
	return e
end
