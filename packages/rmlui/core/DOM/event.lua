
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
	end
	return e
end
