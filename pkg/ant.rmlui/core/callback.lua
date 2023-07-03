local console = require "core.sandbox.console"
local filemanager = require "core.filemanager"
local constructor = require "core.DOM.constructor"
local environment = require "core.environment"
local event = require "core.event"
local parsetext=require "core.parsetext"
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
function m.OnCreateElement(document, element, name)
	local globals = environment[document]
	if not globals then
		return
	end
	local window = globals.window
	local ctor = window.customElements.get(name)
	if not ctor then
		return
	end
	ctor(constructor.Element(document, false, element))
end
function m.OnDestroyNode(document, node)
	event("OnDestroyNode", document, node)
end

local maxEventId = 0
local function genEventId()
	maxEventId = maxEventId + 1
	return maxEventId
end
function m.OnEventAttach(document, element, source)
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
	local ok, f = invoke(payload, constructor.Element(document, false, element))
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
	local eventid = genEventId()
	events[eventid] = {f, upvalue.event}
	return eventid
end
function m.OnEvent(eventid, e)
	local delegate = events[eventid]
	if not delegate then
		return
	end
	local f = delegate[1]
	if delegate[2] then
		debug.setupvalue(f, delegate[2], constructor.Event(e))
	end
	invoke(f)
end
function m.OnEventDetach(eventid)
	events[eventid] = nil
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