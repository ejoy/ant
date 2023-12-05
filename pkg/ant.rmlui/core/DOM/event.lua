local rmlui = require "rmlui"
local environment = require "core.environment"
local constructor = require "core.DOM.constructor"

return function (e)
	if e.target then
		local document = rmlui.ElementGetOwnerDocument(e.target)
		e.target = constructor.Element(document, false, e.target)
		e.current = constructor.Element(document, false, e.current)
	end
	return e
end
