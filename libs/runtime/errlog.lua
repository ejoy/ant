local ru = require 'runtime.util'

ru.createThread('errlog', [[
	local thread = require "thread"
	local err = thread.channel "errlog"
	while true do
		print("ERROR:" .. err:bpop())
	end
]])
