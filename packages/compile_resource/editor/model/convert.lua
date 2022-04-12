local glb = require "editor.model.glb"
local datalist = require "datalist"
local fs = require "filesystem.local"

local function readdatalist(filepath)
	local f = assert(fs.open(filepath, "r"))
	local data = f:read "a"
	f:close()
	return datalist.parse(data,function(args)
		return args[2]
	end)
end

return function (input, output, _, localpath)
	local config = readdatalist(input)
    local path = localpath(config.path)
    local ok, res = glb(path, output, nil, localpath)
    if not ok then
        return ok, res
    end
    table.insert(res, 1, input)
    return ok, res
end
