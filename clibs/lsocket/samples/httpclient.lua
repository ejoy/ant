-- example for lsocket: a simple http client.
--
-- Gunnar Zötl <gz@tset.de>, 2013-2015
-- Released under the terms of the MIT license. See file LICENSE for details.

ls = require "lsocket"

url = arg[1]
if url == nil then
	error("Usage: " .. arg[0] .. " <url>")
end

if not string.find(url, "^http://") then
	error("only http urls supported.")
end

local host, port, path = string.match(url, "^http://([^:/]+):?(%d*)(/?.*)$")
if not host then
	error("invalid url.")
end
if #port == 0 then port = 80 end
if #path == 0 then path = "/" end

sock, err = ls.connect(host, port)
if not sock then
	error(err)
end

-- wait for connect() to succeed or fail
ls.select(nil, {sock})
ok, err = sock:status()
if not ok then
	error(err)
end

rq = "GET " .. path .. " HTTP/1.1\r\n"
rq = rq .. "Host: " .. host .. ":" .. port .. "\r\n"
rq = rq .. "Connection: close\r\n"
rq = rq .. "\r\n"

-- normally you would not need to be so fussy about such a small data
-- package, it should be sent in one go anyways. This here is just to
-- illustrate how data should be sent to a non-blocking socket.
sent = 0
repeat
	ls.select(nil, {sock})
	sent = sent + sock:send(string.sub(rq, sent, -1))
until sent == #rq

-- now we read the reply, which can be larger than the max amount of
-- bytes that will be sent in one tcp packet. So looping really makes
-- sense here :) We requested the server to close the connection after
-- the data was sent, so we can just wait for recv() to return nil, and
-- then consider all data to be received.
reply = ""
repeat
	ls.select({sock})
	str, err = sock:recv()
	if str then
		reply = reply .. str
	elseif err then
		error(err)
	end
until not str

print(reply)
