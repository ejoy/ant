local glb = require "editor.model.glb"
local datalist = require "datalist"
local fs = require "filesystem.local"
local depends   = require "editor.depends"

local function readdatalist(filepath)
	local f = assert(fs.open(filepath, "r"))
	local data = f:read "a"
	f:close()
	return datalist.parse(data,function(args)
		return args[2]
	end)
end

return function (input, output, localpath)
	local config = readdatalist(input)
    local path = localpath(config.path)
    local ok, res = glb(path, output, localpath)
    if not ok then
        return ok, res
    end
    depends.insert_front(res, input)
    return ok, res
end
