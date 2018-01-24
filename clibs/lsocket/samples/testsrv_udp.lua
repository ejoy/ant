-- very simple udp test server that just echoes what it gets from the clients.
-- Demonstrates how to set up a udp server socket, how to accept connections,
-- and how to maintain multiple connections in parallel.
--
-- Gunnar Zötl <gz@tset.de>, 2013-2015
-- Released under the terms of the MIT license. See file LICENSE for details.

if arg[1] == '6' then
	addr = '::1'
else
	addr = '127.0.0.1'
end
port = 8000

ls = require "lsocket"

server, err = ls.bind("udp", addr, port)
if not server then
	print("error: "..err)
	os.exit(1)
end

print "Socket info:"
for k, v in pairs(server:info()) do
	io.write(k..": "..tostring(v)..", ")
end
sock = server:info("socket")
print("\nSocket: "..sock.family.." "..sock.addr..":"..sock.port)

repeat
	ready = ls.select {server}
	
	str, addr, port = server:recvfrom()
	if str ~= nil then
		str = string.gsub(str, "\n$", "")
		print("from "..addr..":"..tostring(port).." got '"..str.."', answering...")
		server:sendto("You sent: "..str.."\n", addr, port)
	else
		print("error: "..err)
	end
until false
