-- very simple udp test client, just connects to the server, sends what
-- you type and prints what you receive.
-- Demonstrates how to set up a udp client socket and communicate through
-- it.
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

client, err = ls.connect('udp', addr, port)
if not client then
	print("error: "..err)
	os.exit(1)
end

-- wait for connect() to succeed or fail
ls.select(nil, {client})
ok, err = client:status()
if not ok then
	print("error: "..err)
	os.exit(1)
end

print "Socket info:"
for k, v in pairs(client:info()) do
	io.write(k..": "..tostring(v)..", ")
end
sock = client:info("socket")
print("\nSocket: "..sock.family.." "..sock.addr..":"..sock.port)
peer = client:info("peer")
print("Peer: "..peer.family.." "..peer.addr..":"..peer.port)

print("Type quit to quit.")
repeat
	io.write("Enter some text: ")
	s = io.read()
	ok, err = client:send(s)
	if not ok then print("error: "..err) end
	ls.select({client})
	str, err = client:recv()
	if str then
		print("reply: "..str)
	else
		print("error: "..err)
	end
until s == "quit"

client:close()
