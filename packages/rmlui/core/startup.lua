local console = require "core.console"
local sandbox = require "core.sandbox"
local fileManager = require "core.fileManager"
local event = require "core.event"
local createElement = require "core.DOM.element"
local createEvent = require "core.DOM.event"
local environment = require "core.environment"
local contextManager = require "core.contextManager"
require "core.DOM.document"
require "core.DOM.window"

local m = {}

local events = {}

local function invoke(f, ...)
	local ok, err = xpcall(f, function(msg)
		return debug.traceback(msg)
	end, ...)
	if not ok then
		console.warn(err)
	end
	return ok, err
end
function m.OnDocumentCreate(document)
	local globals = sandbox()
	event("OnDocumentCreate", document, globals)
	globals.window.document = globals.document
	environment[document] = globals
end
function m.OnDocumentDestroy(document)
	event("OnDocumentDestroy", document)
	environment[document] = nil
end
function m.OnLoadInlineScript(document, content, source_path, source_line)
	local path = fileManager.realpath(source_path)
	if not path then
		console.warn(("file '%s' does not exist."):format(source_path))
		return
	end
	local source = "--@"..path..":"..source_line.."\n "..content
	local f, err = load(source, source, "t", environment[document])
	if not f then
		console.warn(err)
		return
	end
	invoke(f)
end
function m.OnLoadExternalScript(document, source_path)
	local path = fileManager.realpath(source_path)
	if not path then
		console.warn(("file '%s' does not exist."):format(source_path))
		return
	end
	local f, err = loadfile(path, "t", environment[document])
	if not f then
		console.warn(err)
		return
	end
	invoke(f)
end
function m.OnEvent(ev, e)
	local delegate = events[ev]
	if not delegate then
		return
	end
	local f = delegate[1]
	if delegate[2] then
		debug.setupvalue(f, delegate[2], createEvent(e))
	end
	invoke(f)
end
function m.OnEventAttach(ev, document, element, source)
	if source == "" then
		return
	end
	local globals = environment[document]
	local code = ("local event;local this=...;return function()%s;end"):format(source)
	local payload, err = load(code, source, "t", globals)
	if not payload then
		console.warn(err)
		return
	end
	local ok, f = invoke(payload, createElement(element, document))
	if not ok then
		return
	end
	local upvalue = {}
	local i = 1
	while true do
		local name = debug.getupvalue(f, i)
		if not name then
			break
		end
		upvalue[name] = i
		i = i + 1
	end
	events[ev] = {f, upvalue.event}
end
function m.OnEventDetach(ev)
	events[ev] = nil
end

function m.OnOpenFile(path)
	return fileManager.realpath(path)
end

function m.OnShutdown()
	contextManager.destroy()
end

m.OnUpdate = require "core.update"

return m
