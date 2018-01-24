lsock = require "lsocket"

if arg[1] == '6' then
	addr = '::1'
else
	addr = '127.0.0.1'
end
port = 8000

-- 1024 byte data package
data = ""
for i = 1, 64 do
	data = data .. "0123456789ABCDEF"
end

function test_tcp()
	local srv = lsock.bind('tcp', addr, port)
	local rsock = lsock.connect('tcp', addr, port)
	lsock.select{srv}			-- ensure srv is ready
	local ssock = srv:accept()
	lsock.select(nil, {rsock})	-- wait for rsock's connection request to be accepted
	local ld = ""
	for sz = 1, 16 do
		ld = ld .. data
		ssock:send(ld)
		lsock.select({rsock})
		local rd = rsock:recv(#ld)
		if ld ~= rd then
			print("tcp test failed for size " .. #ld)
			return false
		end
	end
	rsock:close()
	ssock:close()
	return true
end

function test_udp()
	local ssock = lsock.connect('udp', addr, port)
	local rsock = lsock.bind('udp', addr, port)
	local ld = ""
	for sz = 1, 16 do
		ld = ld .. data
		ssock:sendto(ld, addr, port)
		lsock.select({rsock})
		local rd = rsock:recvfrom(#ld)
		if ld ~= rd then
			print("tcp test failed for size " .. #ld)
			return false
		end
	end
	rsock:close()
	ssock:close()
	return true
end

ok = test_tcp() and test_udp()

print("Test " .. (ok and "passed" or "failed"))
