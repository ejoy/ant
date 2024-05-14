local ltask = require "ltask"
local socket = require "socket"

local fd = ...

local sessions = {}
local session_id = 0
local waiting_request = {}

local function wakeup(s)
	local waiting = #waiting_request
	if waiting > 0 then
		local co = waiting_request[waiting]
		waiting_request[waiting] = nil
		ltask.wakeup(co, s)
	end
end

local function close_session(s)
	local fd = s.fd
	s.fd = nil
	if fd then
		socket.close(fd)
	end
end

local function new_session(client_fd)
	session_id = session_id + 1
	local currrent_session = session_id
	local s = {
		fd = client_fd,
		data = "",
		session = session_id,
	}
	sessions[session_id] = s
	print("New client", currrent_session)
	while true do
		local reading = socket.recv(client_fd)
		if reading == nil then
			break
		end
		local msg = s.data
		if msg == nil then
			break
		end
		msg = msg .. reading
		s.data = msg
		wakeup(s)
	end
	print("Close client", currrent_session)
	s.data = nil
	close_session(s)
	sessions[currrent_session] = nil
	while #waiting_request > 0 do
		wakeup(s)
	end
end

local function main()
	while true do
		local newfd = socket.listen(fd)
		if newfd then
			ltask.fork(new_session, newfd)
		end
	end
end

ltask.fork(main)

local S = {}

function S.REQUEST()
	while true do
		for session, s in pairs(sessions) do
			local data = s.data
			if data ~= "" then
				s.data = ""
				return session, data
			end
		end
		-- wait for socket.recv()
		local token = ltask.running()
		waiting_request[#waiting_request+1] = token
		local s = ltask.wait(token)
		local data = s.data
		if data ~= "" then
			if data then
				s.data = ""
				return s.session, data
			else
				return s.session
			end
		end
		-- retry
	end
end

-- resp == nil means close the session
function S.RESPONSE(session, resp)
	local s = sessions[session]
	if s == nil then
		return
	end
	if resp == nil then
		close_session(s)
	else
		if s.fd then
			if socket.send(s.fd, resp) == nil then
				close_session(s)
			end
		end
	end
end

function S.QUIT()
	for _, s in pairs(sessions) do
		close_session(s)
	end
	socket.close(fd)
	ltask.quit()
end

return S
