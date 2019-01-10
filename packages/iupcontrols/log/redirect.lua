local lsocket = require "lsocket"
local redirectfd = require "redirectfd"

local function create_pipe()
	local port = 10000
	local socket

	repeat
		socket = lsocket.bind( "127.0.0.1", port)
		if not socket then
			port = port + 1
		end
	until socket

	local ofd = assert(lsocket.connect("127.0.0.1", port))
	lsocket.select {socket}
	local ifd = socket:accept()
	socket:close()
	lsocket.select({}, {ofd})
	return ifd,ofd
end


local redirect = {}

local stdhandle = {
	stdout = 1,
	stderr = 2,
}

local handle = {}
local handle_set = {}

local function dispatch()
	local r, err = lsocket.select(handle_set, 0)
	if r then
		for _, fd in ipairs(r) do
			handle_set[fd](fd:recv())
		end
	elseif r == nil then
		error(err)
	end
end

redirectfd_table = {}
function redirect.callback(what, f)
	local h = handle[what]
	if not h then
		local sfd = stdhandle[what]
		local ifd,ofd = create_pipe()

		--if is standard output then
		if sfd then
			redirectfd.init(ofd:info().fd, sfd)
		else
			redirectfd_table[what] = {ifd = ifd, ofd = ofd}
		end

		handle[what] = { input = ifd, output = ofd }
		h = ifd
		table.insert(handle_set, ifd)
	end
	handle_set[h] = assert(f)

	redirect.dispatch = dispatch
end

function redirect.dispatch()
end

return redirect
