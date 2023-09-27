local ltask = require "ltask"
local socket = require "socket"

local fd = ...

local sessions = {}
local session_id = 0
local waiting_request = {}

local function new_session(client_fd)
	session_id = session_id + 1
	local s = {
		fd = client_fd,
		data = "",
		session = session_id,
	}
	sessions[session_id] = s
	print("New client", session_id)
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
		local waiting = #waiting_request
		if waiting > 0 then
			local co = waiting_request[waiting]
			waiting_request[waiting] = nil
			ltask.wakeup(co, s)
		end
	end
	print("Close client", session_id)
	s.data = nil
	s.fd = nil
	sessions[session_id] = nil
	socket.close(client_fd)
end

local function main()
	while true do
		local newfd = socket.listen(fd)
		ltask.fork(new_session, newfd)
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
		local token = coroutine.running()
		waiting_request[#waiting_request+1] = token
		local s = ltask.wait(token)
		local data = s.data
		if data ~= "" then
			s.data = ""
			return s.session, data
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
		if s.fd then
			socket.close(s.fd)
		end
	else
		if s.fd then
			socket.send(s.fd, resp)
		end
	end
end

function S.QUIT()
	for _, s in pairs(sessions) do
		if s.fd then
			socket.close(s.fd)
			s.fd = nil
		end
	end
	socket.close(fd)
	ltask.quit()
end

return S
