-- very simple test server that just echoes what it gets from the clients.
-- Demonstrates how to set up a unix domain server socket, how to accept
-- connections, how to maintain multiple connections in parallel, and
-- how to determine whether a client has disconnected.
--
-- Gunnar Zötl <gz@tset.de>, 2014-2015
-- Released under the terms of the MIT license. See file LICENSE for details.

addr = "./testsocket"

ls = require "lsocket"

server, err = ls.bind(addr, nil, 10)
if not server then
	print("error: "..err)
	os.exit(1)
end

print "Socket info:"
for k, v in pairs(server:info()) do
	io.write(k..": "..tostring(v)..", ")
end
sock = server:info("socket")
print("\nSocket: "..sock.family.." "..sock.addr)

sockets = {server}

function add_socket(sock)
	sockets[#sockets+1] = sock
end
	
function remove_socket(sock)
	local i, s
	for i, s in ipairs(sockets) do
		if s == sock then
			table.remove(sockets, i)
			return
		end
	end
end

repeat
	ready = ls.select(sockets)
	
	for _, s in ipairs(ready) do
		if s == server then
			local s1 = s:accept()
			print("Connection established, socket "..tostring(s1))
			add_socket(s1, ip)
		else
			local str, err = s:recv()
			if str ~= nil then
				str = string.gsub(str, "\n$", "")
				print("from "..tostring(s).." got '"..str.."', answering...")
				s:send("You sent: "..str.."\n")
			elseif err == nil then
				print("client on socket "..tostring(s).." disconnected")
				s:close()
				remove_socket(s)
			else
				print("error: "..err)
			end
		end
	end
until false
