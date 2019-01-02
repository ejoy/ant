--luacheck: globals iup

package.cpath = "bin/?.dll"
package.path = "?.lua;libs/?.lua;libs/?/?.lua"

require( "iuplua" )
local lc = require "editor.controls.listctrl"

local l = lc.new()

local ex = iup.expander {
	TITLE="ANIMATION",
	l.list
}

local dlg = iup.dialog {
	ex
}

local fs = require "filesystem"

local rootdir = fs.path "d:/Work"
local function fill_content(rootdir)
	l:clear()
	l:append_item("[..]", rootdir:string())	
	local dirs, files = {}, {}
	for d in rootdir:list_directory() do
		local fullpath = rootdir / d
		if fu.isdir(fullpath) then
			table.insert(dirs, {'[' .. d:string() .. ']', fullpath})
		else
			table.insert(files, {d:string(), fullpath})
		end
	end

	for _, d in ipairs(dirs) do
		l:append_item(d[1], d[2])
	end

	for _, f in ipairs(files) do
		l:append_item(f[1], f[2])
	end
	
	iup.Map(l.view)
end

function l.view:dblclick_cb(item, text)
	local ud = l.ud
	local fullpath = ud[item]
	assert(fullpath)
	if text == "[..]" then
		local parentpath = fullpath:parent()
		if parentpath then
			fill_content(parentpath)
		end
	else
		if fs.is_directory(fullpath) then
			fill_content(fullpath)
		end
	end
end

dlg:showxy(iup.CENTER, iup.CENTER)

fill_content(rootdir)

iup.MainLoop()
