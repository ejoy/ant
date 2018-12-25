local ru = require 'runtime.util'

ru.createThread('errlog', [[
	local thread = require "thread"
	local err = thread.channel_consume "errlog"
	while true do
		log.error("ERROR:" .. err())
	end
]])
