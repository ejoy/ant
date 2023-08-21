local ltask = require "ltask"

local socket = {}

local SERVICE_NETWORK <const> = ltask.queryservice "s|network"

function socket.connect(...)
	return ltask.call(SERVICE_NETWORK, "connect", ...)
end

function socket.bind(...)
	return ltask.call(SERVICE_NETWORK, "bind", ...)
end

function socket.listen(fd)
	return ltask.call(SERVICE_NETWORK, "listen", fd)
end

function socket.send(fd, data)
	return ltask.call(SERVICE_NETWORK, "send", fd, data)
end

function socket.recv(fd, n)
	return ltask.call(SERVICE_NETWORK, "recv", fd, n)
end

function socket.close(fd)
	return ltask.call(SERVICE_NETWORK, "close", fd)
end

return socket
