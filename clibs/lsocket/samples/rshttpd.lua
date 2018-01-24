--[[ ridiculously simple http server (library)

	An example for lsocket

	Gunnar Zötl <gz@tset.de>, 2013-2015
	Released under the terms of the MIT license. See file LICENSE for details.

	use:
	
	httpd = require "rshttpd"
	
	-- create server
	server = httpd.new([addr], port, [ [backlog], logfn])

	- Arguments:
		- addr		local ip address to bind to
		- port		local port to bind to
		- backlog	maximum unhandled connection requests
		- logfn		function to do out logging
	- returns the http server object

	-- add request method handler
	server:add_handler("get", function(rq, header, data)
		...
		return "200", "All went well"
	end)

	- for each method METHOD you want to support, you can create a handler
	  by calling the method addhandler with a string containing METHOD in
	  lower case(!) as the first and the handler function as the second
	  argument.

	  For the handler function,
		- Arguments:
			- rq		request data (url, peer, ...)
			- header	table of header fields
			- data		request body data
		- Returns: status, res, hdr
			- status	http status code, usually 200
			- res		data to send to client
			- hdr		(optional) table of additional header fields to send to client.

	-- run server
	repeat
		server:step([timeout])
		-- do some other stuff
	until done

	- server:step() returns true if sockets were handled, or false if the
	  internal call to select() timed out.

	-- request a status
	status = server:status()
	
	- server:status returns a table with these fields:
		- methods		supported methods
		- rqlen			number of sockets waiting to read data
		- wqlen			number of sockets waiting to send data
		- nreqs			number of requests served
		- up_since		date and time when the server has been started

	-- handling keepalive connections
	
	Connections are persistent (keep-alive) if requested by the client or
	if the http version is 1.1 or more and the client does not forbid them
	by requesting Connection: Close. The life time of a keepalive connection
	can be set by setting server.keepalive to a value in seconds, default
	is 10. If you do not want to support persistent connections, set
	server.keepalive to false.

	-- Notes:
	
	As reads and writes in lsocket are non-blocking, and the data may not
	be sent or received in one go from / to the socket, we set up the handlers
	for the connections as coroutines. Whenever a handling process wants
	some data, it enters its socket into a watch list for select, makes
	a note of which coroutine to resume if the socket becomes ready for
	read, and then yields. When data becomes ready, the coroutine will
	be resumed, reads data from the socket and continues its processing.
	Similarly for writing, we write as much as we can in one go and then
	yield until we can write more. Repeat until all is written.
--]]

local ls = require "lsocket"

local gsub = string.gsub
local char = string.char
local format = string.format
local byte = string.byte
local sub = string.sub
local find = string.find
local match = string.match
local lower = string.lower
local yield = coroutine.yield
local date = os.date
local time = os.time
local remove = table.remove

local http_status_msg = {
	["100"] = "Continue",
	["101"] = "Switching Protocols",
	["200"] = "OK",
	["201"] = "Created",
	["202"] = "Accepted",
	["203"] = "Non-Authoritative Information",
	["204"] = "No Content",
	["205"] = "Reset Content",
	["206"] = "Partial Content",
	["300"] = "Multiple Choices",
	["301"] = "Moved Permanently",
	["302"] = "Found",
	["303"] = "See Other",
	["304"] = "Not Modified",
	["305"] = "Use Proxy",
	["307"] = "Temporary Redirect",
	["400"] = "Bad Request",
	["401"] = "Unauthorized",
	["402"] = "Payment Required",
	["403"] = "Forbidden",
	["404"] = "Not Found",
	["405"] = "Method Not Allowed",
	["406"] = "Not Acceptable",
	["407"] = "Proxy Authentication Required",
	["408"] = "Request Time-out",
	["409"] = "Conflict",
	["410"] = "Gone",
	["411"] = "Length Required",
	["412"] = "Precondition Failed",
	["413"] = "Request Entity Too Large",
	["414"] = "Request-URI Too Large",
	["415"] = "Unsupported Media Type",
	["416"] = "Requested range not satisfiable",
	["417"] = "Expectation Failed",
	["500"] = "Internal Server Error",
	["501"] = "Not Implemented",
	["502"] = "Bad Gateway",
	["503"] = "Service Unavailable",
	["504"] = "Gateway Time-out",
	["505"] = "HTTP Version not supported",
}

-- add socket to a waiting queue
local function add_to_queue(tbl, sock)
	local tid = #tbl + 1
	tbl[tid] = sock
	return tid
end

-- remove socket from a waiting queue
-- the sockets index in the queue may have been moved down by other
-- remove()s, so we search backwards from the old position - or the
-- current table length, whichever is smaller.
local function remove_from_queue(tbl, sock, tid)
	local ts = #tbl
	tid = tid or ts
	tid = tid < ts and tid or ts
	while tid > 0 do
		if tbl[tid] == sock then
			remove(tbl, tid)
			break
		end
		tid = tid - 1
	end
end

-- insert socket into appropriate table and then return to main loop.
-- It will resume here when the socket becomes ready for the operation
-- we want to perform
local function waitfor(self, what, sock)
	local tbl = self[what]
	local tid = add_to_queue(tbl, sock)
	self.requests[sock] = coroutine.running()
	coroutine.yield()
	self.requests[sock] = nil
	remove_from_queue(tbl, sock, tid)
end

-- wrappers around socket:recv and socket:send that wrap the concurrency
-- (as described above) into nice little functions using waitfor() above
local function recv_data(self, sock)
	waitfor(self, "rsocks", sock)
	local ok, err = sock:recv()
	if not ok and err then error(err) end
	return ok
end

local function send_data(self, sock, data)
	waitfor(self, "wsocks", sock)
	local ok, err = sock:send(data)
	if not ok then error(err) end
	return ok
end

-- helpers, and also utility methods for the httpd lib
local function urldecode(str)
	str = gsub(str, "+", " ")
	str = gsub(str, "%%(%x%x)",
		function(h) return char(tonumber(h,16)) end)
	str = gsub (str, "\r\n", "\n")
  return str
end

local function urlencode(str)
	if (str) then
		str = gsub(str, "\n", "\r\n")
		str = gsub(str, "([^%w ])",
			function (c) return format ("%%%02X", byte(c)) end)
		str = gsub (str, " ", "+")
	end
	return str	
end

-- helper for the read_request function: ensure that there is an entire
-- line present in the data read from the socket, read more if necessary
-- and return the line (and aux data) if there is one.
local function next_line(self, sock, buf, pos)
	while not find(buf, "\n", pos, true) do
		local sb, err = recv_data(self, sock)
		if not sb then error(err) end
		buf = buf .. sb
	end
	local b, e, str = find(buf, "^([^\r\n]*)\r?\n", pos)
	return b, e, str, buf
end

-- reads the entire request data and returns
-- - information about the request (method, url, peer, ...)
-- - the request headers as a table
-- - the request body
local function read_request(self, sock)
	local request, header, body
	local method, url, httpver, path, args
	local pos = 1

	-- read request line
	local b, e, ln, rq = next_line(self, sock, "", pos)
	method, url, httpver = match(ln, "^(%a+)%s+([^%s]+)%s+HTTP/([%d.]+)$")
	if not method then return error("can't find request line") end
	if find(url, "?", 1, true) then
		path, args = match(url, "^([^?]+)%?(.+)$")
	else
		path = url
	end
	
	request = {
		method = lower(method),
		url = url,
		path = urldecode(path),
		args = args,
		httpver = tonumber(httpver),
		peer = sock:info("peer")
	}
	pos = e + 1

	-- read header
	header = {}
	repeat
		b, e, ln, rq = next_line(self, sock, rq, pos)
		if #ln > 0 then
			local name, val = match(ln, "^([^%s:]+)%s*:%s*(.+)$")
			header[lower(name)] = urldecode(val)
		end
		pos = e + 1
	until #ln == 0

	-- read body
	if header["content-length"] then
		local clen = tonumber(header["content-length"])
		while #rq - pos + 1 ~= clen do
			rq = rq .. recv_data(self, sock)
		end
		body = sub(rq, pos, pos + clen - 1)
	end

	return request, header, body
end

-- main function to process a request. This is what runs in a coroutine,
-- yielding when a recv() or send() operation would block. See send_data
-- and recv_data above.
local function process_request(self, sock)
	-- read request data
	local rq, headers, body = read_request(self, sock)
	local ok, status, res, hdr, answer, smsg, k, v
	local keepalive = false
	local conn = lower(headers.connection)

	-- check whether we can process the request. If so, call the handler
	if rq.httpver < 1.0 or rq.httpver > 1.1 then
		res = "<html><head>Error</head><body><h1>HTTP version not supported</h1></body></html>"
		status = "505"
	else
		if rq.method ~= nil and self.process[lower(rq.method)] ~= nil then
			ok, status, res, hdr = pcall(self.process[lower(rq.method)], rq, headers, body)
		end
		
		if self.keepalive and (conn == 'keep-alive' or
			(rq.httpver >= 1.1 and conn ~= 'close')) then
			keepalive = true
		end
		
		-- check return status
		if ok then
			res = res or "(no data)"
			status = tostring(status)
		elseif not ok and res == nil then
			res = "<html><head>Error</head><body><h1>Internal Error</h1>"
			res = res .. "<p>" .. status .. "</p></body></html>"
			status = "500"
			keepalive = false
		else
			res = "<html><head>Error</head><body><h1>Not Implemented</h1></body></html>"
			status = "501"
			keepalive = false
		end
	end

	-- compose reply to client: a simple http header and the result of the
	-- handler as body.
	smesg = http_status_msg[status] or "unknown status"
	self:log(sock:info("peer").addr, rq.method, rq.url, "HTTP/" .. tostring(rq.httpver), status, smesg)
	answer = "HTTP/" .. rq.httpver .. " " .. status .. " " .. smesg .. "\r\n"
	answer = answer .. "Content-Type: text/html\r\n"
	answer = answer .. "Content-Length: " .. tostring(#res) .. "\r\n"

	if keepalive then
		answer = answer .. "Connection: Keep-Alive\r\n"
		answer = answer .. "Keep-Alive: timeout=" .. self.keepalive .. "\r\n"
	end

	if hdr then
		for k, v in pairs(hdr) do
			answer = answer .. k .. ": " .. tostring(v) .. "\r\n"
		end
	end
	answer = answer .. "\r\n"
	answer = answer .. res

	-- send reply to client.
	local tosend, sent = #answer, 0
	repeat
		sent = sent + send_data(self, sock, sub(answer, sent + 1, -1))
	until sent == tosend
	
	if keepalive then
		self.stillalive[sock] = time() + self.keepalive
		add_to_queue(self.rsocks, sock)
	else
		sock:close()
	end
	self.nreqs = self.nreqs + 1
	
	return true
end

-- start a coroutine to handle the request. Perform initial call to
-- coroutine with httpd object and client socket.
local function begin_request(self, sock)
	local cr = coroutine.create(process_request)
	local ok, err = coroutine.resume(cr, self, sock)
	if not ok then
		self:log(err)
		sock:close()
	end
	return ok
end

-- continue processing of request: find coroutine that handles socket and
-- resume it
local function continue_request(self, sock)
	local cr = self.requests[sock]
	local ok, err = coroutine.resume(cr)
	if not ok then
		self:log(err)
		sock:close()
	end
	return ok
end

local httpd = {}
local httpd_methods = {}

-- create a new httpd object
function httpd.new(addr, port, backlog, logfn)
	local emsg

	-- check whether optional addr has been omitted
	if tonumber(addr) then
		logfn, backlog, port, addr = backlog, port, addr, ls.INADDR_ANY
	end
	backlog = backlog or 10

	local self = setmetatable({}, {__index = httpd_methods})
	
	self.socket, emsg = ls.bind(addr, port, backlog)
	if not self.socket then
		error(emsg)
	end

	self.rsocks = { self.socket }
	self.wsocks = {}
	self.requests = {}
	self.stillalive = {}
	self.keepalive = 10 -- seconds
	self.logfn = logfn
	self.started = time()
	self.nreqs = 0

	-- dummy handler
	self.process = {
		get = function(rq, header) return "200", "<html><body><pre>"..rq.url.."</pre></body></html>" end
	}

	return self
end

-- perform logs from the httpd object. May be called by the objects request
-- handler, and also by client code.
function httpd_methods:log(...)
	if self.logfn then
		self.logfn(date("%Y-%m-%d %H:%M:%S ") .. table.concat({...}, " "))
	end
end

-- request a status from the server.
function httpd_methods:status()
	local methods, m, _ = {}
	for m, _ in pairs(self.process) do
		methods[#methods+1] = m
	end
	return {
		methods = methods,
		rqlen = #self.rsocks,
		wqlen = #self.wsocks,
		nreqs = self.nreqs,
		up_since = os.date("%Y-%m-%d %H:%M:%S", self.started)
	}
end

-- add a handler for a request method to the httpd object. See comment at
-- the beginning of this file for how the handler should look.
function httpd_methods:addhandler(rq, fn)
	if type(rq) == "string" and type(fn) == "function" then
		self.process[rq] = fn
	elseif type(rq) ~= "string" then
		error("addhandler: invalid type for arg#1 (string expected)")
	elseif type(fn) ~= "function" then
		error("addhandler: invalid type for arg#2 (function expected)")
	end
end

-- perform one step (i.e. select, handle sockets that became ready, return)
-- returns true if sockets were handled, false if select() timed out.
function httpd_methods:step(tmout)
	local server = self.socket
	local _, s, t
	local rr, rw = ls.select(self.rsocks, self.wsocks, tmout)

	-- handle sockets from the read queue: they may be either new connections,
	-- reused keep-alive connections or running requests
	if rr then
		for _, s in ipairs(rr) do
			if s == server then
				local s1, ip, port = s:accept()
				begin_request(self, s1)
			elseif self.stillalive[s] then
				self.stillalive[s] = nil
				remove_from_queue(self.rsocks, s)
				begin_request(self, s
)			else
				continue_request(self, s)
			end
		end
	end
	
	-- handle sockets from write queue: these can only be running requests
	if rw then
		for _, s in ipairs(rw) do
			continue_request(self, s)
		end
	end
	
	-- clean up timed out keepalive connections
	local tm = time()
	for s, t in pairs(self.stillalive) do
		if t <= tm then
			self.stillalive[s] = nil
			s:close()
		end
	end
	
	return not not rr
end

httpd.urldecode = urldecode
httpd.urlencode = urlencode

return httpd
