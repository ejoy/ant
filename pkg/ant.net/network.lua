local net = {}

function net.new(selector)
	local api = {}

	local ltask = require "ltask"
	local socket = require "bee.socket"
	local bee_select = require "bee.select"
	local SELECT_READ <const> = bee_select.SELECT_READ
	local SELECT_WRITE <const> = bee_select.SELECT_WRITE

	local fd_id = 1
	local listen_fds = {}
	local fds = {}

	local wakeup = ltask.wakeup

	function api.listen(addr, port)
		local fd, err = socket.create "tcp"
		if not fd then
			return false, err
		end
		fd:option("reuseaddr", 1)
		local ok, err = fd:bind(addr, port)
		if not ok then
			fd:close()
			return false, err
		end
		local ok, err = fd:listen()
		if not ok then
			fd:close()
			return false, err
		end
		local obj = {
			fd = fd
		}
		local id = fd_id; fd_id = fd_id + 1
		listen_fds[id] = obj
		local function accept_fd()
			local newfd, err = fd:accept()
			if not newfd then
				selector:event_del(fd)
				fd:close()
				table.insert(obj, err)
			else
				table.insert(obj, newfd)
				if obj.co then
					wakeup(obj.co)
					obj.co = nil
				end
			end
		end
		selector:event_add(fd, SELECT_READ, accept_fd)
		return id
	end

	local function new_fd(fd)
		local id = fd_id; fd_id = fd_id + 1
		local obj = {
			fd = fd,
			flag = 0,
			update = nil,
		}
		function obj.update(event)
			if (event & SELECT_READ) ~= 0 then
				wakeup(obj.rd)
				obj.rd = nil
			elseif (event & SELECT_WRITE) ~= 0 then
				wakeup(obj.wt)
				obj.wt = nil
			end

			obj.flag = obj.flag & ~event
			selector:event_mod(obj.fd, obj.flag)
		end
		selector:event_add(fd, 0, obj.update)
		fds[id] = obj
		return id
	end

	local function get_fd(obj)
		local fd = table.remove(obj, 1)
		if type(fd) == "string" then
			return false, fd
		end
		return new_fd(fd)
	end

	function api.accept(fd)
		local obj = assert(listen_fds[fd])
		if obj[1] then
			return get_fd(obj)
		end
		assert(obj.co == nil)
		obj.co = ltask.running()
		ltask.wait(obj.co)
		return get_fd(obj)
	end

	function api.connect(addr, port)
		local fd, err = socket.create "tcp"
		if not fd then
			return false, err
		end
		local ok, err = fd:connect(addr, port)
		if err then
			return false, err
		end
		local id = new_fd(fd)
		local obj = fds[id]
		obj.wt = ltask.running()
		selector:event_mod(obj.fd, SELECT_WRITE)
		ltask.wait(obj.wt)
		return true, id
	end

	local function add_event(obj, flag)
		obj.flag = obj.flag | flag
		selector:event_mod(obj.fd, obj.flag)
	end

	function api.recv(fd)
		local obj = assert(fds[fd])
		local content, err = obj.fd:recv()
		if content == false then
			-- block
			assert(obj.rd == nil)
			obj.rd = ltask.running()
			add_event(obj, SELECT_READ)
			local rd = obj.rd
			ltask.wait(rd)
			content, err = obj.fd:recv()
		end
		return content, err
	end

	local function send(fd, content)
		local obj = fds[fd]
		if not obj then
			return nil, "Closed"
		end
		local n, err = obj.fd:send(content)
		if n == false then
			-- block
			assert(obj.wt == nil)
			obj.wt = ltask.running()
			add_event(obj, SELECT_WRITE)
			ltask.wait(obj.wt)
			n, err = obj.fd.send(content)
		end
		if not n then
			if n == false then
				n = 0
			else
				return nil, err
			end
		end
		return content:sub(n+1)
	end

	function api.send(fd, content)
		local err
		repeat
			content, err = send(fd, content)
		until not content or content == ""
		return err
	end

	function api.close(fd)
		local obj = fds[fd]
		if obj then
			selector:event_del(obj.fd)
			obj.fd:close()
			fds[fd] = nil
		else
			obj = listen_fds[fd]
			if obj then
				selector:event_del(obj.fd)
				obj.fd:close()
				listen_fds[fd] = nil
			end
		end
	end
	return api
end

return net
