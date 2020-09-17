local thread = require 'runtime.thread'

thread.create('errlog', [[
	local thread = require "thread"
	local err = thread.channel_consume "errlog"
	while true do
		log.error("ERROR:" .. err())
	end
]])
