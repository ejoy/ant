function log(name)
	local tag = "[" .. name .. "] "
	return function(fmt, ...)
		print(tag .. string.format(fmt, ...))
	end
end
