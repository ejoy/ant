local environment = require "core.environment"

local event_type = {
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
