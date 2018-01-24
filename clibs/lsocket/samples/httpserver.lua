-- example for lsocket: a http server, using the rshttpd lib
-- this is extremely simple, just echoes back the request headers and
-- request details
--
-- Gunnar Zötl <gz@tset.de>, 2013-2015
-- Released under the terms of the MIT license. See file LICENSE for details.

httpd = require "rshttpd"

local server = httpd.new('0.0.0.0', 8000, 1000, print)

local function tablify(tbl)
	local res = '<table style="border: 1px solid grey">'
	local k, v
	for k, v in pairs(tbl) do
		res = res .. '<tr><th align="right" valign="top" style="border: 1px solid grey">' .. k .. "</th><td>"
		if type(v) == "table" then
			res = res .. tablify(v)
		else
			res = res .. tostring(v)
		end
		res = res .. "</td></tr>"
	end
	res = res .. "</table>"
	return res
end

server:addhandler("post", function(rq, header, data)
	local res = table.concat{
		"<html><head><title>", rq.url, "</title></head><body><pre>",
		'<h1><b>POST</b> ', rq.url, "</h1>",
		"<h2>Header</h2>",
		tablify(header),
		"<h2>Request</h2>",
		tablify(rq),
		"<b>data:</b><br>", data, "<br>",
		"<br>" .. _VERSION .. "<br>",
		"</pre></body></html>"}
	return "200", res, { ["X-MyCustomHeader"] = "MyValue" }
end)

server:addhandler("get", function(rq, header)
	local res = table.concat {
		"<html><head><title>", rq.url, "</title></head><body><pre>",
		'<h1><b>GET</b> ', rq.url, "</h1>"}
	if rq.path == "/status" then
		res = res .. "<h2>Status</h2>" .. tablify(server:status())
	else
		res = res .. table.concat{
			"<h2>Header</h2>",
			tablify(header),
			"<h2>Request</h2>",
			tablify(rq)}
	end
	res = res .. "<br>" .. _VERSION .. "<br>"
	res = res .. "</pre></body></html>"
	return "200", res, { ["X-MyCustomHeader"] = "MyValue" }
end)

local doomsday = false

repeat
	server:step(0.1)
until doomsday
