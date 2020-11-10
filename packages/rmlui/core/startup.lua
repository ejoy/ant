local console = require "core.console"
local sandbox = require "core.sandbox"

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

function m.OnContextCreate(context)
end
function m.OnContextDestroy(context)
end
function m.OnNewDocument(document)
	environment[document] = sandbox()
end
function m.OnDeleteDocument(document)
	environment[document] = nil
end
function m.OnInlineScript(document, source)
	local f, err = load(source, source, "t", environment[document])
	if not f then
		console.warn(err)
		return
	end
	local ok, err = xpcall(f, function(msg)
		return debug.traceback(msg)
	end)
	if not ok then
		console.warn(err)
	end
end
function m.OnExternalScript(document, source)
	local f, err = load(assert(rmlui.RmlReadFile(source)), "@"..source, "t", environment[document])
	if not f then
		console.warn(err)
		return
	end
	local ok, err = xpcall(f, function(msg)
		return debug.traceback(msg)
	end)
	if not ok then
		console.warn(err)
	end
end
function m.OnEvent(ev, params, id)
	local f = events[ev]
	if not f then
		return
	end
	f(id, params)
end
function m.OnEventAttach(ev, document, element, source)
	if source == "" then
		return
	end
	local f, err = load(source, source, "t", environment[document])
	if not f then
		console.warn(err)
		return
	end
	events[ev] = f
end
function m.OnEventDetach(ev)
	events[ev] = nil
end

m.OnUpdate = require "core.update"

return m
