local ltask = require "ltask"
local httpd = require "http.httpd"
local urllib = require "http.url"

local ServiceIO = ltask.queryservice "io"
local WEB_TUNNEL <const> = "WEBTUN"

local socket_error = setmetatable({} , { __tostring = function() return "[Socket Error]" end })

local function iofuncs(port)
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
				waiting = coroutine.running()
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
						waiting = coroutine.running()
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

local sessions = {}

local function response(session, write, ...)
	local ok, err = httpd.write_response(write, ...)
	if not ok then
		if err ~= socket_error then
			print(string.format("session = %s, %s", session, err))
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

local function route_vfs(route, cgi)
	return function (s)
		local code, url, method, header, body = httpd.read_request(s.read)
		if code then
			if code ~= 200 then
				response(id, s.write, code)
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
						local f = m[method]
						if f == nil then
							response(id, s.write, 500, lua_error_temp:format ("Unsupport method : " .. method))
							return
						end
						local ok, code, data, header = xpcall(f, debug.traceback, path, query, header, body)
						if ok then
							response(id, s.write, code, data, header)
						else
							response(id, s.write, 500, lua_error_temp:format(escape_html(code)))
						end
					else
						response(id, s.write, 500, lua_error_temp:format(escape_html(m)))
					end
				else
					-- static files in vfs
					local mapping = route[root]
					if not mapping then
						mapping = route["/"]
						if not mapping then
							response(id, s.write, 403, "ERROR 403 : " ..  fullpath .. " not found")
							return
						end
						root = "/"
						path = fullpath:match "^/?(.*)"
					else
						root = "/" .. root .. "/"
					end
					local ok, code, data, header = xpcall(webvfs.get, debug.traceback, path, root, mapping)
					if ok then
						response(id, s.write, code, data, header)
					else
						response(id, s.write, 500, lua_error_temp:format(escape_html(code)))
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

		sessions[s] = nil
	end
end

local S = {}

function S.start(conf)
	local S = ltask.dispatch()
	local port = tostring(conf.port)

	-- todo: support multiple port
	assert(S[WEB_TUNNEL] == nil, "webserver already start")
	print ("Webserver start at", port)

	local iof = iofuncs(port)
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

	setmetatable(sessions , {
		__index = function(o, session)
			local s = iof(session)
			o[session] = s
			ltask.fork(http_request,s)
			return s
		end
	})

	S[WEB_TUNNEL] = function (port, session, req)
		local s = sessions[session]
		s.append(req)
	end

	ltask.send(ServiceIO, "REDIRECT", WEB_TUNNEL, ltask.self())
	ltask.send(ServiceIO, "SEND", "TUNNEL_OPEN", port, WEB_TUNNEL)
end

return S
