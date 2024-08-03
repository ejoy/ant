local ltask = require "ltask"

local function keys(o)
	local len = #o
	local skeys = {}
	local ukeys = {}
	local n = 1
	for k,v in pairs(o) do
		local nk = math.tointeger(k)
		if nk == nil or nk <= 0 or nk > len then
			local sk = tostring(k)
			if type(k) == "string" then
				skeys[n] = k; n = n + 1
			else
				ukeys[k] = true
			end
		end
	end
	table.sort(skeys)
	for k in pairs(ukeys) do
		skeys[n] = k; n = n + 1
	end
	return skeys
end

local function try_no_circular(o)
	local cache = {}
	local function seri_no_circular(o)
		assert(cache[o] == nil, cache)
		if type(o) == "table" then
			local result = { "{" }
			local n = 2
			cache[o] = true
			for i = 1, #o do
				local v = o[i]
				result[n] = seri_no_circular(v); n = n + 1
				result[n] = " "; n = n + 1
			end
			local key = keys(o)
			for i = 1, #key do
				local k = key[i]
				local v = seri_no_circular(o[k])
				result[n] = seri_no_circular(k); n = n + 1
				result[n] = ":"; n = n + 1
				result[n] = v; n = n + 1
				result[n] = " "; n = n + 1
			end
			result[n] = "}"
			return table.concat(result)
		else
			return tostring(o)
		end
	end
	
	local ok, r = pcall(seri_no_circular, o)
	if not ok then
		if r == cache then
			return
		else
			error(r)
		end
	end
	return r
end

local function mark_circular(o)
	local cache = {}
	local n = 1
	local function mark(o)
		if type(o) == "table" then
			local v = cache[o]
			if v == nil then
				cache[o] = false
			else
				if v == false then
					cache[o] = n; n = n + 1
				end
				return
			end
			for k,v in pairs(o) do
				mark(k)
				mark(v)
			end
		end
	end
	mark(o)
	for k,v in pairs(cache) do
		if not v then
			cache[k] = nil
		end
	end
	return cache
end

local function seri_circular(o)
	local cache = mark_circular(o)
	local function seri_object(o)
		if type(o) ~= "table" then
			return tostring(o)
		end
		local result
		local s = cache[o]
		if s then
			if type(s) == "number" then
				result = { "#"..s.."{" }
				cache[o] = "[#"..s.."]"
			else
				return s
			end
		else
			result = { "{" }
		end
		
		local n = 2
		for i = 1, #o do
			local v = o[i]
			result[n] = seri_object(v); n = n + 1
			result[n] = " "; n = n + 1
		end
		local key = keys(o)
		for i = 1, #key do
			local k = key[i]
			local v = seri_object(o[k])
			result[n] = seri_object(k); n = n + 1
			result[n] = ":"; n = n + 1
			result[n] = v; n = n + 1
			result[n] = " "; n = n + 1
		end
		result[n] = "}"
		return table.concat(result)
	end
	return seri_object(o)
end

local function seri(o)
	return try_no_circular(o) or seri_circular(o)
end

local function print_r(...)
	local len = select("#", ...)
	if len == 1 then
		log.info_(seri(...))
	else
		local r = {}
		local n = 1
		for i = 1, len do
			local o = select(i, ...)
			r[n] = seri(o); n = n + 1
		end
		log.info_(table.concat(r, "\t"))
	end
end

return print_r