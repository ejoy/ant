local console = require "core.console"
local sandbox = require "core.sandbox"
local filemanager = require "core.filemanager"
local event = require "core.event"
local createElement = require "core.DOM.element"
require "core.DOM.document"
require "core.window"

local m = {}

local event_name = {
	[0] = "invalid",
	"mousedown"     ,
	"mousescroll"   ,
	"mouseover"     ,
	"mouseout"      ,
	"focus"         ,
	"blur"          ,
	"keydown"       ,
	"keyup"         ,
	"textinput"     ,
	"mouseup"       ,
	"click"         ,
	"dblclick"      ,
	"load"          ,
	"unload"        ,
	"show"          ,
	"hide"          ,
	"mousemove"     ,
	"dragmove"      ,
	"drag"          ,
	"dragstart"     ,
	"dragover"      ,
	"dragdrop"      ,
	"dragout"       ,
	"dragend"       ,
	"handledrag"    ,
	"resize"        ,
	"scroll"        ,
	"animationend"  ,
	"transitionend" ,
	"change"        ,
	"submit"        ,
	"tabchange"     ,
	"columnadd"     ,
	"rowadd"        ,
	"rowchange"     ,
	"rowremove"     ,
	"rowupdate"     ,
}

local environment = {}
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

function m.OnContextCreate(context)
	event("OnContextCreate", context)
end
function m.OnContextDestroy(context)
	event("OnContextDestroy", context)
end
function m.OnNewDocument(document)
	local globals = sandbox()
	event("OnNewDocument", document, globals)
	environment[document] = globals
end
function m.OnDeleteDocument(document)
	event("OnDeleteDocument", document)
	environment[document] = nil
end
function m.OnInlineScript(document, source)
	local f, err = load(source, source, "t", environment[document])
	if not f then
		console.warn(err)
		return
	end
	invoke(f)
end
function m.OnExternalScript(document, source)
	local path = filemanager.realpath(source)
	if not path then
		console.warn(("file '%s' does not exist."):format(source))
		return
	end
	local f, err = loadfile(path, "t", environment[document])
	if not f then
		console.warn(err)
		return
	end
	invoke(f)
end
function m.OnEvent(ev, params, id)
	local f = events[ev]
	if not f then
		return
	end
	invoke(f, id, params)
end
function m.OnEventAttach(ev, document, element, source)
	if source == "" then
		return
	end
	local globals = environment[document]
	local code = ("local this=...;return function()%s;end"):format(source)
	local payload, err = load(code, source, "t", globals)
	if not payload then
		console.warn(err)
		return
	end
	local ok, f = invoke(payload, createElement(globals.document, element))
	if not ok then
		return
	end
	events[ev] = f
end
function m.OnEventDetach(ev)
	events[ev] = nil
end

function m.OnOpenFile(path)
	return filemanager.realpath(path)
end

m.OnUpdate = require "core.update"

return m
