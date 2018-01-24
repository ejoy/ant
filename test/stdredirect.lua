dofile "libs/init.lua"

require "scintilla"

local redirect = require "filesystem.redirect"

iup.SetGlobal("UTF8MODE", "YES")

local editor = iup.scintilla {
	MARGINWIDTH0 = "20",
	STYLEFONT33 = "Consolas",
	STYLEFONTSIZE33 = "11",
	STYLEVISIBLE33 = "NO",
	expand = "YES",
	WORDWRAP = "CHAR",
	APPENDNEWLINE = "NO",
}

print(iup.GetAttributeId(editor, "STYLEVISIBLE", 33))
iup.SetAttributeId(editor, "STYLEFONT", 33, "Consolas")
iup.SetAttributeId(editor, "STYLEFONTSIZE", 33, "11")

dlg = iup.dialog {
--  canvas,
	editor,
  title = "Output",
  size = "QUARTERxQUARTER"
}

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

redirect.callback("stdout", function(txt)
	editor.append = txt
end)

print "Hello"
print "World"

iup.SetIdle(function ()
	redirect.dispatch()
	return iup.DEFAULT
end)

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
end
