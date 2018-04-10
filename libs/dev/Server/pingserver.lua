local pingserver = {}

function pingserver.PING(req)
	return { "PONG" }
end

return pingserver
