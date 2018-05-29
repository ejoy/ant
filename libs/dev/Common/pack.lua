local pack = {}

function pack.pack(p)
	local tmp = {}
	for _, str in ipairs(p) do
		table.insert(tmp, string.pack("<s2", str))
	end
	return string.pack("<s2", table.concat(tmp))
end

function pack.unpack(str, pack)
	pack = pack or {}
	local off = 1
	local len = #str
	while off <= len do
		local ok, part, idx = pcall(string.unpack,"<s2", str, off)
		if ok then
			table.insert(pack, part)
			off = idx
		else
			-- invalid pack
			return
		end
	end
	return pack
end

function pack.send(fd, queue)
	while true do
		local s = queue[1]
		if not s then
			return
		end
		local nbytes = fd:send(s)
		if not nbytes then
			return
		end
		if nbytes == #s then
			table.remove(queue, 1)
		else
			queue[1] = s:sub(nbytes+1)
			return
		end
	end
end

return pack
