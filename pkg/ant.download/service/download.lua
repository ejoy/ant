local ltask = require "ltask"
local download = require "download"

local downloading = ltask.queryservice "ant.download|downloading"

ltask.call(downloading, "init", ltask.self())

local S = {}

local session = 0

local sessions = {}

local function new_session()
	session = session + 1
	return session
end

local function start(id)
	local s = sessions[id]
	ltask.call(downloading, "download", id, s.url, s.filename)
	sessions[id] = nil
	ltask.send(downloading, "finish", id)
end

function S.start(url, filename)
	local id = new_session()
	local s = {
		url = url,
		filename = filename,
	}
	sessions[session] = s
	ltask.fork(start, id)
	return id
end

function S._p(id, p, m, status)
	local s = sessions[id]
	if not s then
		return
	end
	s.p = p
	s.m = m
	s.status = status
	if s.waiting then
		ltask.wakeup(s)
	end
end

function S._c(id, cancel)
	local s = sessions[id]
	if s then
		s.cancel = cancel
	end
end

function S.cancel(id)
	local s = sessions[id]
	if s then
		if s.cancel then
			download.cancel(s.cancel)
			s.cancel = nil
		end
	end
end

function S.progress(id)
	local s = sessions[id]
	if not s then
		return true
	end
	if s.waiting then
		return false
	end
	while true do
		if s.status then
			local p, m, status = s.p, s.m, s.status
			s.p = nil
			s.m = nil
			s.status = nil
			return status, p, m
		end
		s.waiting = true
		ltask.wait(s)
		s.waiting = nil
	end
end

return S
