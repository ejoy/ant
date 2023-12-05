require "core.event.dom"
local textureloader = require "core.textureloader"
local constructor = require "core.DOM.constructor"
local environment = require "core.environment"
local event = require "core.event"
local parsetext = require "core.parsetext"
local eventListener = require "core.event.listener"
local document_manager = require "core.document_manager"

local m = {}

function m.OnCreateElement(document, element, tagName)
	local globals = environment[document]
	if globals then
		local window = globals.window
		local ctor = window.customElements.get(tagName)
		if ctor then
			ctor(constructor.Element(document, false, element))
		end
	end
	event("OnCreateElement", document, element)
end
function m.OnCreateText(document, node)
	event("OnCreateText", document, node)
end
function m.OnDestroyNode(document, node)
	event("OnDestroyNode", document, node)
end

function m.OnDispatchEvent(document, element, type, eventData)
	eventListener.dispatch(document, element, type, eventData)
end

function m.OnLoadTexture(doc, e, path, width, height, isRT)
	document_manager.updatePendingTexture(doc, 1)
	textureloader.loadTexture(doc, e, path, width, height, isRT)
end

function m.OnParseText(str)
	return parsetext.ParseText(str)
end

return m
