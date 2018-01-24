-- very simple multicast test client, just listens to a multicast address
-- and prints what it receives.
-- Demonstrates how to set up a multicast client socket and read data
-- from it.
--
-- Gunnar Zötl <gz@tset.de>, 2013-2015
-- Released under the terms of the MIT license. See file LICENSE for details.

if arg[1] == '6' then
	addr = 'ff01::1'
else
	addr = '127.255.255.255'
end
port = 8000

ls = require "lsocket"

client, err = ls.bind('mcast', addr, port)
if not client then
	print("error: "..err)
	os.exit(1)
end

print "Socket info:"
for k, v in pairs(client:info()) do
	io.write(k..": "..tostring(v)..", ")
end
sock = client:info("socket")
print("\nSocket: "..sock.family.." "..sock.addr..":"..sock.port)

repeat
	ls.select {client}
	str, ip, port = client:recvfrom()
	if str then
		print("received from "..ip..":"..port..": "..str)
	else
		print("error: "..ip)
	end
until false

client:close()
