--luacheck: globals iup

package.cpath = "bin/?.dll"
package.path = "?.lua;libs/?.lua;libs/?/?.lua"

require( "iuplua" )
local lc = require "editor.controls.listctrl"

local l = lc.new()

local dlg = iup.dialog {
	l.list,
}

local fu = require "filesystem.util"
local path = require "filesystem.path"

local rootdir = "d:/Work"
local function fill_content(rootdir)
	l:clear()
	l:append_item("[..]", rootdir)	
	local dirs, files = {}, {}
	for d in fu.dir(rootdir) do
		local fullpath = path.join(rootdir, d)
		if fu.isdir(fullpath) then
			table.insert(dirs, {'[' .. d .. ']', fullpath})
		else
			table.insert(files, {d, fullpath})
		end
	end

	for _, d in ipairs(dirs) do
		l:append_item(d[1], d[2])
	end

	for _, f in ipairs(files) do
		l:append_item(f[1], f[2])
	end
	
	iup.Map(l.list)
end

function l.list:dblclick_cb(item, text)
	local ud = l.ud
	local fullpath = ud[item]
	assert(fullpath)
	if text == "[..]" then
		local parentpath = path.parent(fullpath)
		if parentpath then
			fill_content(parentpath)
		end
	else
		if fu.isdir(fullpath) then
			fill_content(fullpath)
		end
	end
end

dlg:showxy(iup.CENTER, iup.CENTER)

fill_content(rootdir)

iup.MainLoop()
