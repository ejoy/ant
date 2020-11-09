local m = {}
function m.OnContextCreate(context)
	print("Create Context", context)
end
function m.OnContextDestroy(context)
	print("Destroy Context", context)
end
function m.OnNewDocument(doc)
	print("Document Open", doc)
end
function m.OnDeleteDocument(doc)
	print("Document Close", doc)
end
function m.OnLoadScript(source, doc, filename)
	print("Document:", doc)
	print(source)
	print(rmlui.DocumentGetSourceURL(doc))
	local f,err = load(source)
	if err then
		print("Load error:", err)
	else
		print(pcall(f, doc))
	end
end
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
function m.OnEvent(ev, params, id)
	print("Event", ev, event_name[id])
	if params then
		for k,v in pairs(params) do
			print("=>", k,v)
		end
	end
end
function m.OnEventAttach(ev, document, element, source)
	print("EventAttach", ev)
	print("Document:", document)
	print("Element:", element)
	print(source)
end
function m.OnEventDetach(ev)
	print("EventDetach", ev)
end

return m
