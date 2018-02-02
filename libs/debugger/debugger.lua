local modname, filename = ...

local rdb = require "remotedebug"

local debugserver = filename:gsub("[^/\\]+$","server.lua")

rdb.start "debugger.server"

local debugger = {}

function debugger.traceback(...)
	rdb.probe "traceback"
	return debug.traceback(...)
end

return debugger
