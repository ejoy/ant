
require "scintilla"

local redirect = require "filesystem.redirect"
local task = require "editor.task"

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

local log_tabs = { value = "error" }

local function append_text(ctrl)
	return function(txt)
		ctrl.READONLY = "NO"
		ctrl.append = txt
		ctrl.READONLY = "YES"
		ctrl.SCROLLBY = ctrl.LINECOUNT
	end
end

for _, v in ipairs {
	"stdout",
	"stderr",
	} do
	log[v] = new_logger(v)
	table.insert(log_tabs, log[v])
	redirect.callback(v, append_text(log[v]))
end

do
	local err_log = new_logger "error"
	table.insert(log_tabs, err_log)
	local append_error = append_text(err_log)
	function log.print(...)
		local tmp = table.pack(...)
		local text = table.concat(tmp, "\t", 1, tmp.n)
		append_error(text)
	end
	function log.active_error()
		log.window.VALUE = err_log
	end
end

local function error_cb(co)
	local trace = debug.traceback(co)
	log.print(trace)
	log.active_error()
end

do
	local bgfx_log = new_logger "bgfx"
	table.insert(log_tabs, bgfx_log)
	local append_bgfxlog = append_text(bgfx_log)
	local function fetch_bgfxlog()
		local bgfx = require "bgfx"
		local msg = bgfx.get_log()
		if msg and #msg ~= 0 then
			append_bgfxlog(msg)
		end
	end

	task.loop(fetch_bgfxlog, error_cb)
end

log.window =  iup.tabs(log_tabs)

task.loop(redirect.dispatch, error_cb)

return log
