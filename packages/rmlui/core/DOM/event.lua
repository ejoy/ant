local rmlui = require "rmlui"
local environment = require "core.environment"
local constructor = require "core.DOM.constructor"

return function (e)
	if e.target then
		local document = rmlui.ElementGetOwnerDocument(e.target)
		e.target = constructor.Element(document, false, e.target)
		e.current = constructor.Element(document, false, e.current)
		if e.type == "message" then
			if e.source == nil then
				e.source = environment[document].window
			elseif e.source == "extern" then
				e.source = environment[document].window.extern
			else
				e.source = constructor.Window(e.source, document)
			end
		end
	end
	return e
end
