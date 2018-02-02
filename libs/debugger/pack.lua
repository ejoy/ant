local lsocket = require "lsocket"

local package = {}	; package.__index = package

function package.new(fd)
	return setmetatable( {
		_data = "",
		_fd = fd,
	} , package)
end

local srd = {}
local function get_size(self, sz)
	local n = #self._data
	if sz <= n then
		local ret = self._data:sub(1,sz)
		self._data = self._data:sub(sz+1)
		return ret
	else
		while true do
			local data, err = self._fd:recv()
			if data then
				self._data = self._data .. data
				return get_size(self,sz)
			elseif data == false then
				-- block
				srd[1] = fd
				lsocket.select(srd)
			else
				return nil, "Socket : " .. tostring(err)
			end
		end
	end
end

function package:recv()
	local header = assert(get_size(self, 4))	-- 4 bytes header
	local size = string.unpack("I4", header)
	return assert(get_size(self, size))
end

function package:send(data)
	data = string.pack("s4", data)
	local nbytes = assert(self._fd:send(data))
	local n = #data
	while nbytes < n do
		local bytes = assert(self._fd:send(data:sub(nbytes + 1)))
		nbytes = nbytes + bytes
	end
end

return package
