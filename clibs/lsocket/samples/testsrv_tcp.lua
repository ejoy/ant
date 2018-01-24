-- very simple tcp test server that just echoes what it gets from the clients.
-- Demonstrates how to set up a tcp server socket, how to accept connections,
-- how to maintain multiple connections in parallel, and how to determine
-- whether a client has disconnected.
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

server, err = ls.bind(addr, port, 10)
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

sockets = {server}
socketinfo = {}

function add_socket(sock, ip, port)
	sockets[#sockets+1] = sock
	socketinfo[sock] = ip..":"..port
end
	
function remove_socket(sock)
	local i, s
	for i, s in ipairs(sockets) do
		if s == sock then
			table.remove(sockets, i)
			socketinfo[sock] = nil
			return
		end
	end
end

repeat
	ready = ls.select(sockets)
	
	for _, s in ipairs(ready) do
		if s == server then
			local s1, ip, port = s:accept()
			print("Connection established from "..ip..", port "..port)
			add_socket(s1, ip, port)
		else
			i = socketinfo[s]
			local str, err = s:recv()
			if str ~= nil then
				str = string.gsub(str, "\n$", "")
				print("from "..i.." got '"..str.."', answering...")
				s:send("You sent: "..str.."\n")
			elseif err == nil then
				print("client "..i.." disconnected")
				s:close()
				remove_socket(s)
			else
				print("error: "..err)
			end
		end
	end
until false
