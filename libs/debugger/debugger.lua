local modname, filename = ...

local rdb = require "remotedebug"

local debugserver = filename:gsub("[^/\\]+$","server.lua")

rdb.start "debugger.server"

local debugger = {}
local type = type
local probe = rdb.probe

function debugger.traceback(co, ...)
	if type(co) == "thread" then
		probe(co, "traceback")
	else
		probe("traceback")
	end
	return debug.traceback(co, ...)
end

return debugger
