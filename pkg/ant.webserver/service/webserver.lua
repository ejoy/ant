local ltask = require "ltask"
local httpd = require "http.httpd"
local urllib = require "http.url"

local socket_error = setmetatable({} , { __tostring = function() return "[Socket Error]" end })

local mod = {}

function mod.direct(conf, http_request)
	local net = import_package "ant.net"
	local addr = conf.addr or "127.0.0.1"
	local port = assert(conf.port)
	local listen_fd = assert(net.listen(addr, port))

	local function net_api(fd)
		local obj = {}
		local buf = ""
		function obj.read(size)
			if size == nil then
				if buf == "" then
					return net.recv(fd)
				else
					local r = buf
					buf = ""
					return r
				end
			end
			while size > #buf do
				local c, err = net.recv(fd)
				if not c then
					error(socket_error)
				end
				buf = buf .. c
			end

			local r = buf:sub(1, size)
			buf = buf:sub(size + 1)
			return r
		end

		function obj.write(content)
			local err = net.send(fd, content)
			if err then
				error(socket_error)
			end
		end

		function obj.close()
			net.close(fd)
		end

		return obj
	end

	ltask.fork(function()
		while true do
			local fd = net.accept(listen_fd)
			print("Accept", fd)
			if fd then
				ltask.fork(http_request, net_api(fd))
			end
		end
	end)
end

function mod.redirect(conf, http_request)
	local ServiceIO = ltask.queryservice "io"
	local WEB_TUNNEL <const> = "WEBTUN"
	local port = tostring(conf.port)

	local function iofuncs()
		return function (session)
			session = tostring(session)
			local io = {}
			local msg = {}
			local waiting

			function io.append(str)
				msg[#msg+1] = str
				if waiting then
					ltask.wakeup(waiting)
					waiting = nil
				end
			end

			function io.read(size)
				if msg[1] == nil then
					waiting = ltask.running()
					ltask.wait(waiting)
					if msg[1] == nil then
						error(socket_error)
					end
				end
				if size == nil then
					return table.remove(msg, 1)
				else
					local r = msg[1]
					while true do
						local len = #r
						if len > size then
							msg[1] = r:sub(size+1)
							return r:sub(1, size)
						end
						table.remove(msg, 1)
						if len == size then
							return r
						end
						if msg[1] == nil then
							waiting = ltask.running()
							ltask.wait(waiting)
							if msg[1] == nil then
								error(socket_error)
							end
						end
						r = r .. msg[1]
					end
				end
			end

			-- tunnel don't support large package
			function io.write(str)
				local n = #str
				local from = 0
				while n >= 0x8000 do
					ltask.send(ServiceIO, "SEND", "TUNNEL_RESP", port, session, str:sub(from + 1, from + 0x8000))
					from = from + 0x8000
					n = n - 0x8000
				end
				if n > 0 then
					ltask.send(ServiceIO, "SEND", "TUNNEL_RESP", port, session, str:sub(from + 1, from + n))
				end
			end

			function io.close()
				ltask.send(ServiceIO, "SEND", "TUNNEL_RESP", port, session)
			end

			return io
		end
	end

	local function init()
		local iof = iofuncs()
		local sessions = {}
		setmetatable(sessions , {
			__index = function(o, session)
				local s = iof(session)
				o[session] = s
				ltask.fork(function()
					http_request(s)
					sessions[s] = nil
				end)
				return s
			end
		})

		local S = ltask.dispatch()
		-- todo: support multiple port
		assert(S[WEB_TUNNEL] == nil, "webserver already start")
		print ("Webserver start at", port)

		S[WEB_TUNNEL] = function (port, session, req)
			local s = sessions[session]
			s.append(req)
		end

		ltask.send(ServiceIO, "REDIRECT", WEB_TUNNEL, ltask.self())
		ltask.send(ServiceIO, "SEND", "TUNNEL_OPEN", port, WEB_TUNNEL)
	end

	init()
end

local function response(write, ...)
	local ok, err = httpd.write_response(write, ...)
	if not ok then
		if err ~= socket_error then
			print(string.format("%s", err))
		end
	end
end

local escapes = {
	['<'] = '&lt;',
	['>'] = '&gt;',
	['"'] = '&quot;',
	["'"] = '&apos;',
	['&'] = '&amp;',
}

local function escape_html(s)
	return (s:gsub("[<>\"\'&]", escapes))
end

local lua_error_temp = [[
<html>
<head><meta charset="utf-8"></head>
<body><pre>
%s
</pre></body>
</html>
]]

local webvfs = require "webvfs"

local S = {}

local function route_vfs(route, cgi)
	return function (s)
		local code, url, method, header, body = httpd.read_request(s.read)
		if code then
			if code ~= 200 then
				response(s.write, code)
			else
				local fullpath, query = urllib.parse(url)
				local root, path = fullpath:match "^/([^/]+)/?(.*)"
				local mod = cgi[root]
				if mod then
					local ok, m = xpcall(import_package, debug.traceback, mod.package)
					if ok then
						if query then
							query = urllib.parse_query(query)
						end
						method = method:lower()
						local m = m[mod.name] or m
						local f = m and m[method]
						if f == nil then
							response(s.write, 500, lua_error_temp:format ("Unsupport method : " .. method))
							return
						end
						local ok, code, data, header = xpcall(f, debug.traceback, path, query, header, body)
						if ok then
							response(s.write, code, data, header)
						else
							response(s.write, 500, lua_error_temp:format(escape_html(tostring(code))))
						end
					else
						response(s.write, 500, lua_error_temp:format(escape_html(m)))
					end
				else
					-- static files in vfs
					local mapping = route[root]
					if not mapping then
						mapping = route["/"]
						if not mapping then
							response(s.write, 403, "ERROR 403 : No web root")
							return
						end
						root = "/"
						path = fullpath:match "^/?(.*)"
					else
						root = "/" .. root .. "/"
					end
					local fsname, fspath = mapping:match "(%w+):(.*)"
					local ok, code, data, header = xpcall(webvfs.get, debug.traceback, fsname, path, root, fspath)
					if ok then
						response(s.write, code, data, header)
					else
						response(s.write, 500, lua_error_temp:format(escape_html(code)))
					end
				end
			end
		else
			if url == socket_error then
				print "socket closed"
			else
				print(url)
			end
		end

		s.close()
	end
end

function S.start(conf)
	if conf.home then
		conf.route["/"] = conf.home
	end
	local cgi = {}
	if conf.cgi then
		for path, pname in pairs(conf.cgi) do
			local package, name = pname:match "(.-)|(.*)"
			if package then
				cgi[path] = { package = package, name = name }
			else
				cgi[path] = { package = pname }
			end
		end
	end

	local http_request = route_vfs(conf.route, cgi)

	local init = mod[conf.mode] or error "Invalid webserver mode " .. conf.mode
	init(conf, http_request)
end

function S.quit()
	ltask.quit()
end

return S
