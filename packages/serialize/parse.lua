local datalist = require "datalist"

local function absolute_path(base, path)
	if path:sub(1,1) == "/" or not base then
		return path
	end
    base = base:match "^(.-)[^/|]*$"
	return base .. (path:match "^%./(.+)$" or path)
end

return function (basepath, data)
    local function convert(args)
        if args[1] == "path" then
            local res = absolute_path(basepath, args[2])
            return res
        end
        return args[2]
    end
    return datalist.parse(data, convert)
end
