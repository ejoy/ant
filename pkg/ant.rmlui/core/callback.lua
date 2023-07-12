local rmlui = require "rmlui"
local console = require "core.sandbox.console"
local filemanager = require "core.filemanager"
local constructor = require "core.DOM.constructor"
local environment = require "core.environment"
local event = require "core.event"
local parsetext = require "core.parsetext"
local datamodel = require "core.datamodel.api"
local m = {}

local function invoke(f, ...)
	local ok, err = xpcall(f, function(msg)
		return debug.traceback(msg)
	end, ...)
	if not ok then
		console.warn(err)
	end
	return ok, err
end

function m.OnLoadInlineScript(document, content, source_path, source_line)
	local f, err = filemanager.loadString(content, source_path, source_line, environment[document])
	if not f then
		console.warn(err)
		return
	end
	invoke(f)
end

function m.OnLoadExternalScript(document, source_path)
	local f, err = filemanager.loadFile(source_path, environment[document])
	if not f then
		console.warn(("file '%s' load failed: %s."):format(source_path, err))
		return
	end
	invoke(f)
end
function m.OnCreateElement(document, element, tagName)
	local globals = environment[document]
	if not globals then
		return
	end
	local window = globals.window
	local ctor = window.customElements.get(tagName)
	if ctor then
		ctor(constructor.Element(document, false, element))
	end
	event("OnCreateElement", document, element)
end
function m.OnDestroyNode(document, node)
	event("OnDestroyNode", document, node)
end

function m.OnDataModelLoad(document, element, name, value)
	datamodel.load(document, element, name, value)
end

function m.OnDataModelRefresh(document)
	datamodel.refresh(document)
end

function m.OnRealPath(path)
	return filemanager.realpath(path)
end

function m.OnLoadTexture(doc, e, path, width, height, isRT)
	filemanager.loadTexture(doc, e, path, width, height, isRT)
end


function m.OnParseText(str)
	return parsetext.ParseText(str)
end

return m