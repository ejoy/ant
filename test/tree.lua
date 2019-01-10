dofile "libs/editor.lua"

require "iuplua"
local redirect = require "filesystem.redirect"
local elog = require "editor.log"
local tree = require "editor.controls.tree"

local t = tree.new()

local dlg = iup.dialog {
	iup.split {
		t.view,
		elog.window,
		SHOWGRIP = "NO",
	},
	title = "tree",
	shrink="yes",
}

local function mainloop(f)
	iup.SetIdle(function ()
		local ok , err = xpcall(f, debug.traceback)
		if not ok then
			print(err)
			iup.SetIdle()
		end
		return iup.DEFAULT
	end)
end

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
mainloop(function()
	redirect.dispatch()
end)

local function init_tree_nodes()
	local b = t:add_child "hello"
	t:add_child(b, "child")
	local w = t:add_child "world"
	t:add_child "foobar"
	t:insert_sibling(w, "slibling")
	t:print()
end

init_tree_nodes()

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
	iup.MainLoop()
	iup.Close()
end
