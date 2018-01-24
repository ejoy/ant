-- very simple multicast test server that just broadcasts a counter.
-- Demonstrates how to set up a multicast server socket, and how to send
-- data to it.
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

server, err = ls.connect("mcast", addr, port)
if not server then
	print("error: "..err)
	os.exit(1)
end

-- wait for connect() to succeed or fail
ls.select(nil, {server})
ok, err = server:status()
if not ok then
	print("error: "..err)
	os.exit(1)
end

print "Socket info:"
for k, v in pairs(server:info()) do
	io.write(k..": "..tostring(v)..", ")
end
sock = server:info("socket")
print("\nSocket: "..sock.family.." "..sock.addr..":"..sock.port)
peer = server:info("socket")
print("Peer: "..peer.family.." "..peer.addr..":"..peer.port)

cnt = 1
repeat
	ready = ls.select(1) -- wait a while
	io.write("sending "..tostring(cnt).."\n")
	server:send("Counting: "..tostring(cnt)) --, addr, port)
	cnt = cnt + 1
until false
