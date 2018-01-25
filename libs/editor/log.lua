require "scintilla"
local redirect = require "filesystem.redirect"

local log = {}

local function new_logger(name)
	return iup.scintilla {
		tabtitle = name,
		MARGINWIDTH0 = "30",	-- line number
		STYLEFONT33 = "Consolas",
		STYLEFONTSIZE33 = "11",
		STYLEVISIBLE33 = "NO",
		expand = "YES",
		WORDWRAP = "CHAR",
		APPENDNEWLINE = "NO",
		READONLY = "YES",
	}
end

local log_tabs = {}

local function append_text(ctrl)
	return function(txt)
		ctrl.READONLY = "NO"
		ctrl.append = txt
		ctrl.READONLY = "YES"
		ctrl.SCROLLBY = ctrl.LINECOUNT
	end
end

for _, v in ipairs { "stdout", "stderr" } do
	log[v] = new_logger(v)
	table.insert(log_tabs, log[v])
	redirect.callback(v, append_text(log[v]))
end

log.window =  iup.tabs(log_tabs)

return log
