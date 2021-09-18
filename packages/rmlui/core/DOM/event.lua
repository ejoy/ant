local environment = require "core.environment"

return function (e)
	if e.target then
		local createElement = require "core.DOM.element"
		e.target = createElement(e.target)
		if e.type == "message" then
			local createWindow = require "core.DOM.window"
			local document = e.target.ownerDocument._handle
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
