require "scintilla"
--[[
multitext = iup.text{
  multiline = "YES",
  expand = "YES"
}
vbox = iup.vbox{
  multitext
}
]]

--canvas = iup.canvas{}
iup.SetGlobal("UTF8MODE", "YES")

local editor = iup.scintilla {
	MARGINWIDTH0 = "20",
	STYLEFONT33 = "Consolas",
	STYLEFONTSIZE33 = "11",
	STYLEVISIBLE33 = "NO",
	expand = "YES",
	WORDWRAP = "CHAR",
}

print(iup.GetAttributeId(editor, "STYLEVISIBLE", 33))
iup.SetAttributeId(editor, "STYLEFONT", 33, "Consolas")
iup.SetAttributeId(editor, "STYLEFONTSIZE", 33, "11")

dlg = iup.dialog {
--  canvas,
	editor,
  title = "Simple Notepad",
  size = "QUARTERxQUARTER"
}


--function canvas:action(...)
--	print(...)
--end

--dlg = iup.scintilladlg{}

editor.append = "你好"

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

--print(iup.GetAttributeData(dlg,"HWND"))
--print(iup.GetAttributeData(dlg,"WID"))

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
  iup.MainLoop()
  iup.Close()
end
